const fs = require('fs');
const path = require('path');
const axios = require('axios');
const { OpenAI } = require('openai');

/**
 * Helper to convert a local file to a base64 string
 */
function fileToBase64(filePath) {
  const fileBuffer = fs.readFileSync(filePath);
  return fileBuffer.toString('base64');
}

/**
 * Downloads an image from a URL and saves it locally
 */
async function downloadImage(url, destPath) {
  const writer = fs.createWriteStream(destPath);
  const response = await axios({
    url,
    method: 'GET',
    responseType: 'stream'
  });
  response.data.pipe(writer);

  return new Promise((resolve, reject) => {
    writer.on('finish', resolve);
    writer.on('error', reject);
  });
}

/**
 * Core image-to-image service utilizing GPT-4o and DALL-E 3
 */
async function generateStyledImage(imagePath, prompt, style, hostUrl) {
  const apiKey = process.env.OPENAI_API_KEY;

  // 1. Mock / Demo Mode
  if (!apiKey || apiKey.trim() === "" || apiKey === "YOUR_OPENAI_API_KEY") {
    console.log(`[AI Stylizer] API Key not set. Running in Mock Mode for style: ${style}`);
    // Simulate API delay
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Copy the corresponding mock image to the generations folder with a unique name
    const mockFilename = `${style}.png`;
    const mockFilePath = path.join(__dirname, '..', '..', 'public', 'mock', mockFilename);
    
    const uniqueName = `gen_${Date.now()}_${Math.floor(Math.random() * 1000)}.png`;
    const targetPath = path.join(__dirname, '..', '..', 'public', 'generations', uniqueName);
    
    if (fs.existsSync(mockFilePath)) {
      fs.copyFileSync(mockFilePath, targetPath);
      return `${hostUrl}/generations/${uniqueName}`;
    } else {
      // Fallback if file doesn't exist
      throw new Error(`Mock file for style ${style} not found`);
    }
  }

  // 2. Real API Mode
  console.log(`[AI Stylizer] Running in Real API Mode for style: ${style}`);
  const openai = new OpenAI({ apiKey });

  try {
    // A. Vision step: Get detailed description from GPT-4o
    const base64Image = fileToBase64(imagePath);
    const mimeType = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';
    
    console.log(`[AI Stylizer] Calling GPT-4o to describe the uploaded image...`);
    const visionResponse = await openai.chat.completions.create({
      model: 'gpt-4o',
      max_tokens: 150,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Analyze this image and describe the main subjects, layout, objects, colors, and composition in detail. Keep the description under 100 words. Focus strictly on content details, ignoring any artistic style or filters.'
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:${mimeType};base64,${base64Image}`
              }
            }
          ]
        }
      ]
    });

    const description = visionResponse.choices[0].message.content.trim();
    console.log(`[AI Stylizer] GPT-4o description: "${description}"`);

    // B. Combine description with the hidden style prompt
    const finalPrompt = `${prompt}\n\nHere is the composition detail of the subjects/scene to draw: ${description}`;
    console.log(`[AI Stylizer] Final generation prompt for DALL-E 3: "${finalPrompt}"`);

    // C. Generate Step: Send prompt to DALL-E 3
    console.log(`[AI Stylizer] Calling DALL-E 3 to generate the image...`);
    const imageResponse = await openai.images.generate({
      model: 'dall-e-3',
      prompt: finalPrompt,
      n: 1,
      size: '1024x1024',
      quality: 'standard'
    });

    const externalUrl = imageResponse.data[0].url;
    console.log(`[AI Stylizer] DALL-E 3 generated image URL: ${externalUrl}`);

    // D. Persistence Step: Download image to static folder
    const uniqueName = `gen_${Date.now()}_${Math.floor(Math.random() * 1000)}.png`;
    const localDestPath = path.join(__dirname, '..', '..', 'public', 'generations', uniqueName);
    
    console.log(`[AI Stylizer] Downloading generated image to: ${localDestPath}`);
    await downloadImage(externalUrl, localDestPath);
    
    return `${hostUrl}/generations/${uniqueName}`;
  } catch (error) {
    console.error(`[AI Stylizer] Error in OpenAI service:`, error);
    console.log(`[AI Stylizer] Falling back to Mock Mode for style: ${style}`);
    
    // Copy the corresponding mock image to the generations folder with a unique name
    const mockFilename = `${style}.png`;
    const mockFilePath = path.join(__dirname, '..', '..', 'public', 'mock', mockFilename);
    
    const uniqueName = `gen_${Date.now()}_${Math.floor(Math.random() * 1000)}.png`;
    const targetPath = path.join(__dirname, '..', '..', 'public', 'generations', uniqueName);
    
    if (fs.existsSync(mockFilePath)) {
      try {
        fs.copyFileSync(mockFilePath, targetPath);
        return `${hostUrl}/generations/${uniqueName}`;
      } catch (copyError) {
        console.error(`[AI Stylizer] Failed to copy mock file during fallback:`, copyError);
        throw error;
      }
    } else {
      console.error(`[AI Stylizer] Mock file for fallback not found: ${mockFilePath}`);
      throw error;
    }
  }
}

module.exports = { generateStyledImage };
