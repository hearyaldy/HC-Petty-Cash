const https = require('https');
const { exec } = require('child_process');

// Get Firebase access token
exec('firebase login:ci --no-localhost', (error, stdout, stderr) => {
  if (error) {
    console.error('Please run: firebase login');
    console.error('Then try this script again');
    process.exit(1);
  }
});

// Alternative: Use REST API with service account
const corsConfig = [
  {
    origin: ['*'],
    method: ['GET', 'HEAD', 'PUT', 'POST', 'DELETE'],
    maxAgeSeconds: 3600,
    responseHeader: ['Content-Type', 'Authorization', 'x-goog-acl', 'x-goog-meta-*']
  }
];

console.log('CORS Configuration to apply:');
console.log(JSON.stringify(corsConfig, null, 2));
console.log('\nPlease configure CORS manually using one of these methods:\n');
console.log('Method 1: Google Cloud Console');
console.log('1. Go to: https://console.cloud.google.com/storage/browser?project=hc-petty-cash-report');
console.log('2. Click on your bucket: hc-petty-cash-report.firebasestorage.app');
console.log('3. Go to "Configuration" tab');
console.log('4. Find "CORS configuration" section');
console.log('5. Click "Edit" and paste the CORS config above');
console.log('6. Click "Save"\n');

console.log('Method 2: Cloud Shell (recommended)');
console.log('1. Go to: https://console.cloud.google.com');
console.log('2. Click the Cloud Shell icon (>_) at the top right');
console.log('3. Run these commands:');
console.log('   cat > cors.json <<EOF');
console.log(JSON.stringify(corsConfig, null, 2));
console.log('   EOF');
console.log('   gsutil cors set cors.json gs://hc-petty-cash-report.firebasestorage.app');
console.log('   gsutil cors get gs://hc-petty-cash-report.firebasestorage.app');
