# Privacy Policy Deployment Guide

## Overview

The privacy policy has been created and is ready to be hosted at `https://sahla-delivery.com/privacy-policy`.

## Files Created

1. **`backend/public/privacy-policy.html`** - The privacy policy HTML document
2. **`backend/src/index.js`** - Updated to serve the privacy policy route

## Deployment Options

### Option 1: Backend API Server (Recommended)

If your backend API is already hosted at `sahla-delivery.com`, the privacy policy will be automatically available at:

- `https://sahla-delivery.com/privacy-policy`

The Express server has been configured to serve the privacy policy from the `/privacy-policy` route.

**To deploy:**

1. Ensure the `backend/public/` directory is included in your deployment
2. Deploy the updated `backend/src/index.js` to your server
3. Restart your Node.js server
4. Verify the privacy policy is accessible at `https://sahla-delivery.com/privacy-policy`

### Option 2: Static Web Server (Alternative)

If you prefer to host the privacy policy on a separate web server (e.g., Nginx, Apache, or a CDN):

1. Copy `backend/public/privacy-policy.html` to your web server's document root
2. Configure your web server to serve the file at `/privacy-policy`
3. Ensure the file is accessible at `https://sahla-delivery.com/privacy-policy`

**Nginx Configuration Example:**

```nginx
location /privacy-policy {
    alias /path/to/privacy-policy.html;
    add_header Content-Type text/html;
}
```

**Apache Configuration Example:**

```apache
Alias /privacy-policy /path/to/privacy-policy.html
```

### Option 3: CDN/Static Hosting (Alternative)

You can also host the privacy policy on:

- AWS S3 + CloudFront
- Cloudflare Pages
- Vercel
- Netlify
- GitHub Pages

Simply upload the `privacy-policy.html` file and configure the URL to be `https://sahla-delivery.com/privacy-policy` (using DNS or redirects).

## Testing

After deployment, test the privacy policy:

1. **Direct URL Test:**

   ```bash
   curl https://sahla-delivery.com/privacy-policy
   ```

2. **Browser Test:**
   Open `https://sahla-delivery.com/privacy-policy` in a web browser

3. **Mobile App Integration:**
   Update your app to link to this URL (see next section)

## Mobile App Integration

To link to the privacy policy from your Flutter app, update your settings/about screen:

```dart
import 'package:url_launcher/url_launcher.dart';

// In your settings screen:
ListTile(
  title: Text('Privacy Policy'),
  trailing: Icon(Icons.arrow_forward_ios),
  onTap: () async {
    final url = Uri.parse('https://sahla-delivery.com/privacy-policy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  },
)
```

## App Store / Play Store Configuration

### Apple App Store

1. Go to App Store Connect
2. Navigate to your app → App Information
3. Add Privacy Policy URL: `https://sahla-delivery.com/privacy-policy`

### Google Play Store

1. Go to Play Console
2. Navigate to your app → Policy → App content
3. Add Privacy Policy URL: `https://sahla-delivery.com/privacy-policy`

## Verification Checklist

- [ ] Privacy policy is accessible at `https://sahla-delivery.com/privacy-policy`
- [ ] Privacy policy renders correctly on mobile devices
- [ ] Privacy policy is linked from app settings/about screen
- [ ] Privacy policy URL is added to App Store Connect
- [ ] Privacy policy URL is added to Play Console
- [ ] Privacy policy content is reviewed and accurate
- [ ] Contact email (privacy@sahla-delivery.com) is set up and monitored

## Updates

To update the privacy policy in the future:

1. Edit `backend/public/privacy-policy.html`
2. Update the "Last Updated" date at the top of the document
3. Redeploy the file to your server
4. Notify users of significant changes (if required by law)

## Contact Information

Make sure to set up the contact email address mentioned in the privacy policy:

- `privacy@sahla-delivery.com`

This email should be monitored for privacy-related inquiries and data deletion requests.
