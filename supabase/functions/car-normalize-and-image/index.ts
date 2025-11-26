import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CarImageProcessingRequest {
  car_id: string
  brand?: string
  model?: string
  year?: number
  force_reprocess?: boolean
}

interface CarsXEResponse {
  images?: Array<{
    url: string
    alt?: string
    caption?: string
  }>
  error?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const carsxeApiKey = Deno.env.get('CARSXE_API_KEY')!
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const { car_id, brand, model, year, force_reprocess }: CarImageProcessingRequest = await req.json()

    if (!car_id) {
      return new Response(
        JSON.stringify({ error: 'car_id is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`🚗 Processing car ${car_id}: brand=${brand}, model=${model}, year=${year}`)

    // Step 1: Normalize brand and model using fuzzy matching
    const normalizationResult = await normalizeCarBrandModel(supabase, car_id, brand, model, year)
    
    if (!normalizationResult.success) {
      return new Response(
        JSON.stringify({ error: normalizationResult.error }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Step 2: Process image pipeline (CarsXE → Library → Background Removal)
    const imageResult = await processCarImagePipeline(
      supabase, 
      carsxeApiKey,
      car_id, 
      normalizationResult.normalized_brand!, 
      normalizationResult.normalized_model!, 
      year
    )

    // Step 3: Update car record with results
    await updateCarImageFields(supabase, car_id, imageResult)

    // Step 4: Log the processing
    await logImageProcessing(supabase, car_id, 'complete', {
      normalization: normalizationResult,
      image_processing: imageResult,
      processing_time_ms: Date.now() - Date.now() // Placeholder for actual timing
    })

    return new Response(
      JSON.stringify({
        success: true,
        normalization: normalizationResult,
        image_processing: imageResult
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error in car-normalize-and-image:', error)
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error', 
        details: error.message 
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Step 1: Normalize brand and model using fuzzy matching
async function normalizeCarBrandModel(supabase: any, carId: string, brand?: string, model?: string, year?: number) {
  try {
    if (!brand || !model) {
      return { success: false, error: 'Brand and model are required for normalization' }
    }

    // Get brand suggestions
    const { data: brandSuggestions, error: brandError } = await supabase.rpc('brand_suggest', {
      q: brand.toLowerCase().trim()
    })

    if (brandError) {
      console.error('Brand suggestion error:', brandError)
      return { success: false, error: `Brand suggestion failed: ${brandError.message}` }
    }

    if (!brandSuggestions || brandSuggestions.length === 0) {
      return { success: false, error: 'No brand suggestions found' }
    }

    const bestBrand = brandSuggestions[0]
    const brandConfidence = bestBrand.score

    // Get model suggestions for the best brand
    const { data: modelSuggestions, error: modelError } = await supabase.rpc('model_suggest', {
      brand_name: bestBrand.name,
      q: model.toLowerCase().trim()
    })

    if (modelError) {
      console.error('Model suggestion error:', modelError)
      return { success: false, error: `Model suggestion failed: ${modelError.message}` }
    }

    const bestModel = modelSuggestions && modelSuggestions.length > 0 ? modelSuggestions[0] : null
    const modelConfidence = bestModel ? bestModel.score : 0.0

    // Update the car record with normalized values
    const { error: updateError } = await supabase
      .from('cars')
      .update({
        normalized_brand: bestBrand.name,
        normalized_model: bestModel ? bestModel.name : model,
        updated_at: new Date().toISOString()
      })
      .eq('id', carId)

    if (updateError) {
      console.error('Update car error:', updateError)
      return { success: false, error: `Failed to update car: ${updateError.message}` }
    }

    console.log(`✅ Normalized: brand="${bestBrand.name}" (${(brandConfidence * 100).toFixed(1)}%), model="${bestModel ? bestModel.name : model}" (${(modelConfidence * 100).toFixed(1)}%)`)

    return {
      success: true,
      normalized_brand: bestBrand.name,
      normalized_model: bestModel ? bestModel.name : model,
      brand_confidence: brandConfidence,
      model_confidence: modelConfidence,
      requires_confirmation: brandConfidence < 0.55 || modelConfidence < 0.55
    }

  } catch (error) {
    console.error('Normalization error:', error)
    return { success: false, error: `Normalization failed: ${error.message}` }
  }
}

// Step 2: Process image pipeline (CarsXE → Library → Background Removal)
async function processCarImagePipeline(
  supabase: any, 
  carsxeApiKey: string,
  carId: string, 
  normalizedBrand: string, 
  normalizedModel: string, 
  year?: number
) {
  try {
    console.log(`🖼️ Processing image pipeline for ${normalizedBrand} ${normalizedModel}`)

    // Step 2a: Try CarsXE API first
    const carsxeResult = await tryCarsXEImage(carsxeApiKey, normalizedBrand, normalizedModel, year)
    if (carsxeResult.success) {
      console.log(`✅ CarsXE image found: ${carsxeResult.image_url}`)
      
      // Upload to Supabase Storage for caching
      const storageResult = await uploadToStorage(supabase, carId, carsxeResult.image_url!, 'carsxe')
      if (storageResult.success) {
        return {
          success: true,
          image_url: storageResult.storage_url,
          image_source: 'carsxe',
          confidence_score: 0.95
        }
      }
    }

    // Step 2b: Try library asset
    const libraryResult = await tryLibraryAsset(supabase, normalizedBrand, normalizedModel, year)
    if (libraryResult.success) {
      console.log(`✅ Library asset found: ${libraryResult.image_url}`)
      return {
        success: true,
        image_url: libraryResult.image_url,
        image_source: 'library',
        confidence_score: 0.90
      }
    }

    // Step 2c: Try background removal on host's first photo
    const bgRemovalResult = await tryBackgroundRemoval(supabase, carId)
    if (bgRemovalResult.success) {
      console.log(`✅ Background removal successful: ${bgRemovalResult.image_url}`)
      return {
        success: true,
        image_url: bgRemovalResult.image_url,
        image_source: 'bg_remove',
        confidence_score: 0.85
      }
    }

    // Step 2d: Try AI generation as final fallback
    const aiGenerationResult = await tryAIGeneration(supabase, normalizedBrand, normalizedModel, year)
    if (aiGenerationResult.success) {
      console.log(`✅ AI generation successful: ${aiGenerationResult.image_url}`)
      return {
        success: true,
        image_url: aiGenerationResult.image_url,
        image_source: 'generated',
        confidence_score: 0.80
      }
    }

    // All methods failed
    console.log(`❌ All image processing methods failed`)
    return {
      success: false,
      error: 'All image processing methods failed'
    }

  } catch (error) {
    console.error('Image pipeline error:', error)
    return {
      success: false,
      error: `Image pipeline failed: ${error.message}`
    }
  }
}

// Step 2a: Try CarsXE API for transparent studio images
async function tryCarsXEImage(apiKey: string, brand: string, model: string, year?: number) {
  try {
    console.log(`🎨 Calling CarsXE API for ${brand} ${model} ${year}`)

    const url = new URL("https://api.carsxe.com/vehicle-images")
    url.searchParams.set("key", apiKey)
    url.searchParams.set("make", brand)
    url.searchParams.set("model", model)
    if (year) url.searchParams.set("year", String(year))
    url.searchParams.set("transparent", "true")
    url.searchParams.set("angle", "front_34") // 3/4 front view

    console.log(`🔗 CarsXE URL: ${url.toString()}`)

    const response = await fetch(url.toString())
    
    if (!response.ok) {
      console.error(`❌ CarsXE API error: ${response.status} ${response.statusText}`)
      return { success: false, error: `CarsXE API error: ${response.status}` }
    }

    const data: CarsXEResponse = await response.json()
    
    if (data.error) {
      console.error(`❌ CarsXE API returned error: ${data.error}`)
      return { success: false, error: data.error }
    }

    if (!data.images || data.images.length === 0) {
      console.log(`❌ No images returned from CarsXE`)
      return { success: false, error: 'No images returned from CarsXE' }
    }

    const imageUrl = data.images[0].url
    console.log(`✅ CarsXE returned image: ${imageUrl}`)

    return { success: true, image_url: imageUrl }

  } catch (error) {
    console.error('CarsXE API error:', error)
    return { success: false, error: `CarsXE API failed: ${error.message}` }
  }
}

// Step 2b: Try to find library asset
async function tryLibraryAsset(supabase: any, brand: string, model: string, year?: number) {
  try {
    console.log(`🔍 Looking for library asset: cars/${brand}/${model}/${year}-hero.png`)

    // Try year-specific hero image first
    if (year) {
      const yearHeroPath = `cars/${brand}/${model}/${year}-hero.png`
      const { data: yearHeroData, error: yearHeroError } = await supabase.storage
        .from('car-library')
        .list(`${brand}/${model}/`, {
          search: `${year}-hero.png`
        })

      if (!yearHeroError && yearHeroData && yearHeroData.length > 0) {
        const { data: signedUrl } = supabase.storage
          .from('car-library')
          .getPublicUrl(yearHeroPath)
        
        if (signedUrl) {
          return { success: true, image_url: signedUrl.publicUrl }
        }
      }
    }

    // Try default model image
    const defaultModelPath = `cars/${brand}/${model}/default.png`
    const { data: defaultModelData, error: defaultModelError } = await supabase.storage
      .from('car-library')
      .list(`${brand}/${model}/`, {
        search: 'default.png'
      })

    if (!defaultModelError && defaultModelData && defaultModelData.length > 0) {
      const { data: signedUrl } = supabase.storage
        .from('car-library')
        .getPublicUrl(defaultModelPath)
      
      if (signedUrl) {
        return { success: true, image_url: signedUrl.publicUrl }
      }
    }

    // Try brand default image
    const defaultBrandPath = `cars/${brand}/default.png`
    const { data: defaultBrandData, error: defaultBrandError } = await supabase.storage
      .from('car-library')
      .list(`${brand}/`, {
        search: 'default.png'
      })

    if (!defaultBrandError && defaultBrandData && defaultBrandData.length > 0) {
      const { data: signedUrl } = supabase.storage
        .from('car-library')
        .getPublicUrl(defaultBrandPath)
      
      if (signedUrl) {
        return { success: true, image_url: signedUrl.publicUrl }
      }
    }

    console.log(`❌ No library assets found for ${brand} ${model}`)
    return { success: false }

  } catch (error) {
    console.error('Library asset lookup error:', error)
    return { success: false }
  }
}

// Step 2c: Try background removal on host's first photo
async function tryBackgroundRemoval(supabase: any, carId: string) {
  try {
    console.log(`🖼️ Attempting background removal for car ${carId}`)

    // Check if background removal is enabled (feature flag)
    const bgRemovalEnabled = Deno.env.get('ENABLE_BG_REMOVAL') === 'true'
    if (!bgRemovalEnabled) {
      console.log(`⏸️ Background removal is disabled`)
      return { success: false }
    }

    // Get car's first uploaded photo
    const { data: carData, error: carError } = await supabase
      .from('cars')
      .select('images, host_id')
      .eq('id', carId)
      .single()

    if (carError || !carData || !carData.images || carData.images.length === 0) {
      console.log(`❌ No images found for car ${carId}`)
      return { success: false }
    }

    const firstImage = carData.images[0]
    console.log(`🖼️ Processing first image: ${firstImage}`)

    // Call background removal service (stub implementation)
    const bgRemovalResult = await callBackgroundRemovalService(firstImage)
    
    if (bgRemovalResult.success) {
      // Upload the processed image to storage
      const processedImagePath = `processed/${carId}/card-bg-removed.png`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('car-images')
        .upload(processedImagePath, bgRemovalResult.image_data, {
          contentType: 'image/png',
          upsert: true
        })

      if (uploadError) {
        console.error('❌ Failed to upload processed image:', uploadError)
        return { success: false }
      }

      // Get public URL
      const { data: signedUrl } = supabase.storage
        .from('car-images')
        .getPublicUrl(processedImagePath)

      return { success: true, image_url: signedUrl.publicUrl }
    }

    return { success: false }

  } catch (error) {
    console.error('Background removal error:', error)
    return { success: false }
  }
}

// Step 2d: Try AI generation as final fallback
async function tryAIGeneration(supabase: any, brand: string, model: string, year?: number) {
  try {
    console.log(`🎨 Attempting AI generation for ${brand} ${model} ${year}`)

    // Check if AI generation is enabled (feature flag)
    const aiGenerationEnabled = Deno.env.get('ENABLE_AI_GENERATION') === 'true'
    if (!aiGenerationEnabled) {
      console.log(`⏸️ AI generation is disabled`)
      return { success: false }
    }

    // Call AI generation service
    const aiGenerationResult = await callAIGenerationService(brand, model, year)
    
    if (aiGenerationResult.success) {
      // Upload the generated image to storage
      const generatedImagePath = `generated/${brand}/${model}/${year || 'modern'}-card.png`
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('car-images')
        .upload(generatedImagePath, aiGenerationResult.image_data, {
          contentType: 'image/png',
          upsert: true
        })

      if (uploadError) {
        console.error('❌ Failed to upload generated image:', uploadError)
        return { success: false }
      }

      // Get public URL
      const { data: signedUrl } = supabase.storage
        .from('car-images')
        .getPublicUrl(generatedImagePath)

      return { success: true, image_url: signedUrl.publicUrl }
    }

    return { success: false }

  } catch (error) {
    console.error('AI generation error:', error)
    return { success: false }
  }
}

// Upload image to Supabase Storage for caching
async function uploadToStorage(supabase: any, carId: string, imageUrl: string, source: string) {
  try {
    console.log(`📤 Uploading ${source} image to storage for car ${carId}`)

    // Fetch the image from the external URL
    const imageResponse = await fetch(imageUrl)
    if (!imageResponse.ok) {
      throw new Error(`Failed to fetch image: ${imageResponse.status}`)
    }

    const arrayBuffer = await imageResponse.arrayBuffer()
    const bytes = new Uint8Array(arrayBuffer)
    
    // Upload to car-cards bucket
    const path = `${carId}/card.png`
    const { error: uploadError } = await supabase.storage
      .from('car-cards')
      .upload(path, bytes, {
        contentType: 'image/png',
        upsert: true
      })

    if (uploadError) {
      console.error('❌ Storage upload error:', uploadError)
      return { success: false, error: uploadError.message }
    }

    // Get signed URL for 1 year
    const { data: signedUrlData, error: signedUrlError } = await supabase.storage
      .from('car-cards')
      .createSignedUrl(path, 60 * 60 * 24 * 365) // 1 year

    if (signedUrlError) {
      console.error('❌ Signed URL error:', signedUrlError)
      return { success: false, error: signedUrlError.message }
    }

    console.log(`✅ Image uploaded successfully to storage`)
    return { success: true, storage_url: signedUrlData.signedUrl }

  } catch (error) {
    console.error('Storage upload error:', error)
    return { success: false, error: error.message }
  }
}

// Step 3: Update car record with image processing results
async function updateCarImageFields(supabase: any, carId: string, imageResult: any) {
  try {
    if (!imageResult.success) {
      console.log(`⚠️ Image processing failed, not updating car fields`)
      return
    }

    const updateData: any = {
      image_card_url: imageResult.image_url,
      image_card_source: imageResult.image_source,
      image_confidence_score: imageResult.confidence_score,
      last_image_update: new Date().toISOString(),
      updated_at: new Date().toISOString()
    }

    const { error } = await supabase
      .from('cars')
      .update(updateData)
      .eq('id', carId)

    if (error) {
      console.error('❌ Failed to update car image fields:', error)
    } else {
      console.log(`✅ Updated car ${carId} with image: ${imageResult.image_url}`)
    }

  } catch (error) {
    console.error('Update car image fields error:', error)
  }
}

// Step 4: Log image processing
async function logImageProcessing(supabase: any, carId: string, status: string, data: any) {
  try {
    const logData = {
      car_id: carId,
      process_type: 'complete_pipeline',
      status: status,
      input_data: data,
      output_data: data,
      processing_time_ms: data.processing_time_ms || 0
    }

    const { error } = await supabase
      .from('car_image_processing_logs')
      .insert(logData)

    if (error) {
      console.error('❌ Failed to log image processing:', error)
    } else {
      console.log(`📝 Logged image processing for car ${carId}`)
    }

  } catch (error) {
    console.error('Log image processing error:', error)
  }
}

// Stub implementations for external services

async function callBackgroundRemovalService(imageUrl: string): Promise<{ success: boolean; image_data?: any }> {
  // This would call an actual background removal service
  // For now, return a stub response
  console.log(`🖼️ Background removal service called for: ${imageUrl}`)
  
  // Check if background removal is enabled (feature flag)
  if (Deno.env.get('ENABLE_BG_REMOVAL') === 'true') {
    console.log(`✅ Background removal is enabled, processing image: ${imageUrl}`)
    
    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 1000))
    
    // Return simulated processed image data
    return { 
      success: true, 
      image_data: {
        processed_url: `https://example.com/processed/${Date.now()}.png`,
        confidence: 0.95,
        processing_time_ms: 1000
      }
    };
  }
  
  console.log(`⏸️ Background removal is disabled`)
  return { success: false };
}

async function callAIGenerationService(brand: string, model: string, year?: number): Promise<{ success: boolean; image_data?: any }> {
  // This would call an actual AI image generation service
  // For now, return a stub response
  console.log(`🎨 AI generation service called for: ${brand} ${model} ${year}`)
  
  // Check if AI generation is enabled (feature flag)
  if (Deno.env.get('ENABLE_AI_GENERATION') === 'true') {
    console.log(`✅ AI generation is enabled, creating image for: ${brand} ${model} ${year}`)
    
    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    // Return simulated generated image data
    return { 
      success: true, 
      image_data: {
        generated_url: `https://example.com/generated/${Date.now()}.png`,
        confidence: 0.90,
        processing_time_ms: 2000,
        prompt_used: `A professional 3D render of a ${year || 'modern'} ${brand} ${model} car in a studio setting with transparent background, 3/4 front view angle`
      }
    };
  }
  
  console.log(`⏸️ AI generation is disabled`)
  return { success: false };
}
