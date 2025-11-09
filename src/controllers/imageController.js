import imageService from '../services/imageService.js';

/**
 * Get category image
 */
export const getCategoryImage = async (req, res) => {
  try {
    const { categoryName } = req.params;
    const { locale = 'en' } = req.query;

    if (!categoryName) {
      return res.status(400).json({ success: false, error: 'Category name is required' });
    }

    const imageBuffer = await imageService.getCategoryImage(categoryName, locale);

    // Set appropriate headers
    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('Content-Length', imageBuffer.length);

    res.send(imageBuffer);
  } catch (error) {
    console.error('Error fetching category image:', error);
    res.status(404).json({ success: false, error: error.message || 'Category image not found' });
  }
};

/**
 * Get menu item image
 */
export const getMenuItemImage = async (req, res) => {
  try {
    const imagePath = decodeURIComponent(req.params.imagePath);

    if (!imagePath) {
      return res.status(400).json({ success: false, error: 'Image path is required' });
    }

    let imageBuffer;
    
    // The service handles both URLs and paths
    imageBuffer = await imageService.getMenuItemImage(imagePath);

    // Determine content type from path or default to jpeg
    const contentType = imagePath.toLowerCase().endsWith('.png')
      ? 'image/png'
      : imagePath.toLowerCase().endsWith('.webp')
      ? 'image/webp'
      : imagePath.toLowerCase().endsWith('.gif')
      ? 'image/gif'
      : 'image/jpeg';

    res.setHeader('Content-Type', contentType);
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('Content-Length', imageBuffer.length);

    res.send(imageBuffer);
  } catch (error) {
    console.error('Error fetching menu item image:', error);
    console.error('Image path:', req.params.imagePath);
    res.status(404).json({ success: false, error: error.message || 'Menu item image not found' });
  }
};

/**
 * Get restaurant logo or cover image
 */
export const getRestaurantImage = async (req, res) => {
  try {
    const { restaurantId, type } = req.params;

    if (!restaurantId) {
      return res.status(400).json({ success: false, error: 'Restaurant ID is required' });
    }

    if (!['logo', 'cover'].includes(type)) {
      return res.status(400).json({ success: false, error: 'Type must be "logo" or "cover"' });
    }

    const imageBuffer = await imageService.getRestaurantImage(restaurantId, type);

    res.setHeader('Content-Type', 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('Content-Length', imageBuffer.length);

    res.send(imageBuffer);
  } catch (error) {
    console.error('Error fetching restaurant image:', error);
    res.status(404).json({ success: false, error: error.message || 'Restaurant image not found' });
  }
};

/**
 * Get LTO card image (same as menu item image)
 */
export const getLTOImage = async (req, res) => {
  try {
    const imagePath = decodeURIComponent(req.params.imagePath);

    if (!imagePath) {
      return res.status(400).json({ success: false, error: 'Image path is required' });
    }

    // The service handles both URLs and paths
    const imageBuffer = await imageService.getMenuItemImage(imagePath);

    const contentType = imagePath.toLowerCase().endsWith('.png')
      ? 'image/png'
      : imagePath.toLowerCase().endsWith('.webp')
      ? 'image/webp'
      : imagePath.toLowerCase().endsWith('.gif')
      ? 'image/gif'
      : 'image/jpeg';

    res.setHeader('Content-Type', contentType);
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('Content-Length', imageBuffer.length);

    res.send(imageBuffer);
  } catch (error) {
    console.error('Error fetching LTO image:', error);
    console.error('Image path:', req.params.imagePath);
    res.status(404).json({ success: false, error: error.message || 'LTO image not found' });
  }
};
