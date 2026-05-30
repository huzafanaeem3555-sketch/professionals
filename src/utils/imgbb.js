const axios = require('axios');
const FormData = require('form-data');

const IMGBB_API_URL = 'https://api.imgbb.com/1/upload';

/**
 * Upload a base64 image to ImgBB (FREE image hosting).
 * Get your free API key at: https://api.imgbb.com
 *
 * @param {string} base64Image - Full base64 string (with or without data:image/... prefix)
 * @param {string} name - Optional image name
 * @returns {{ url, deleteUrl, thumbUrl }}
 */
async function uploadToImgBB(base64Image, name = 'image') {
  const apiKey = process.env.IMGBB_API_KEY || '8f3e5cbd42066c0539ba1b0a8f323fbf';

  if (!apiKey || apiKey === 'your_imgbb_api_key_here') {
    throw new Error('ImgBB API key not configured. Set IMGBB_API_KEY in .env file. Get free key at https://api.imgbb.com');
  }

  // Strip data URL prefix if present
  const base64Data = base64Image.includes(',')
    ? base64Image.split(',')[1]
    : base64Image;

  const formData = new FormData();
  formData.append('key', apiKey);
  formData.append('image', base64Data);
  formData.append('name', name);

  const response = await axios.post(IMGBB_API_URL, formData, {
    headers: formData.getHeaders(),
    timeout: 30000,
  });

  if (!response.data.success) {
    throw new Error('ImgBB upload failed: ' + JSON.stringify(response.data));
  }

  return {
    url: response.data.data.url,
    deleteUrl: response.data.data.delete_url,
    thumbUrl: response.data.data.thumb?.url || response.data.data.url,
    displayUrl: response.data.data.display_url,
  };
}

/**
 * Upload multiple base64 images to ImgBB.
 * Returns array of URLs.
 */
async function uploadMultipleToImgBB(base64Images, namePrefix = 'image') {
  const results = [];
  for (let i = 0; i < base64Images.length; i++) {
    const result = await uploadToImgBB(base64Images[i], `${namePrefix}_${i + 1}`);
    results.push(result.url);
  }
  return results;
}

module.exports = { uploadToImgBB, uploadMultipleToImgBB };
