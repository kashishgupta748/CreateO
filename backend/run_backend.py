import os
import time
import shutil
import random
import base64
import json
import urllib.parse
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

# Set paths
BACKEND_DIR = os.path.abspath(os.path.dirname(__file__))
PUBLIC_DIR = os.path.join(BACKEND_DIR, "public")
MOCK_DIR = os.path.join(PUBLIC_DIR, "mock")
GEN_DIR = os.path.join(PUBLIC_DIR, "generations")

# Create directories if missing
os.makedirs(GEN_DIR, exist_ok=True)
os.makedirs(MOCK_DIR, exist_ok=True)

# Loaded prompts
STYLE_PROMPTS = {
    "sketchbook": """
Transform the uploaded photo into a colorful hand-drawn sketchbook illustration.
Keep the main subject, people, buildings, and composition recognizable.
Use pencil outlines, colored pencil texture, watercolor shading, notebook paper background,
spiral notebook binding on the left, decorative doodles, flowers, stars, books, balloons,
and handwritten scrapbook-style notes.
Make the result feel warm, youthful, emotional, and like a campus memory journal page.
Do not make it photorealistic.
""",
    "anime": """
Convert the uploaded photo into a vibrant anime-style illustration.
Keep the same person and composition recognizable.
Use clean anime line art, expressive eyes, soft cel shading, bright colors,
and polished background details.
Do not make it realistic.
""",
    "watercolor": """
Turn the uploaded photo into a soft watercolor painting.
Preserve the subject and overall composition.
Use gentle washes, artistic edges, pastel tones, and painterly texture.
"""
}

def load_env():
    env = {}
    env_path = os.path.join(BACKEND_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#"):
                    parts = line.split("=", 1)
                    if len(parts) == 2:
                        env[parts[0].strip()] = parts[1].strip()
    return env

class CreateOBackendHandler(BaseHTTPRequestHandler):
    
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status":"healthy","backend":"python-real-api"}')
            return
            
        # Serve static files from public directory
        parsed_path = urllib.parse.urlparse(self.path).path
        relative_path = parsed_path.lstrip("/")
        
        file_path = os.path.abspath(os.path.join(PUBLIC_DIR, relative_path))
        if not file_path.startswith(PUBLIC_DIR):
            self.send_error(403, "Access Denied")
            return
            
        if os.path.exists(file_path) and os.path.isfile(file_path):
            self.send_response(200)
            if file_path.endswith(".png"):
                self.send_header("Content-Type", "image/png")
            elif file_path.endswith(".jpg") or file_path.endswith(".jpeg"):
                self.send_header("Content-Type", "image/jpeg")
            elif file_path.endswith(".json"):
                self.send_header("Content-Type", "application/json")
            else:
                self.send_header("Content-Type", "application/octet-stream")
            
            self.send_header("Content-Length", str(os.path.getsize(file_path)))
            self.end_headers()
            with open(file_path, "rb") as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, f"File Not Found: {self.path}")

    def do_POST(self):
        if self.path == "/api/generate":
            self.handle_generate()
        else:
            self.send_error(404, "Not Found")

    def handle_generate(self):
        try:
            content_type = self.headers.get('Content-Type', '')
            if not content_type.startswith('multipart/form-data'):
                self.send_error(400, "Content-Type must be multipart/form-data")
                return
                
            boundary = content_type.split("boundary=")[1].encode('utf-8')
            content_length = int(self.headers.get('Content-Length', 0))
            
            # Read post body data
            raw_data = self.rfile.read(content_length)
            
            # Extract style
            style = "sketchbook"
            if b'name="style"' in raw_data:
                parts = raw_data.split(b'name="style"')
                if len(parts) > 1:
                    subparts = parts[1].split(b'\r\n\r\n')
                    if len(subparts) > 1:
                        value_part = subparts[1].split(b'\r\n')[0].decode('utf-8').strip()
                        if value_part in ["sketchbook", "anime", "watercolor"]:
                            style = value_part

            # Extract image file content
            # Find the filename start and end of image block
            image_data = None
            if b'filename="' in raw_data:
                parts = raw_data.split(b'Content-Type: image/jpeg\r\n\r\n')
                if len(parts) > 1:
                    # The image data is after Content-Type headers and before the final boundary
                    image_part = parts[1]
                    # The boundary boundary marks the end of image data
                    boundary_marker = b'\r\n--' + boundary
                    image_data = image_part.split(boundary_marker)[0]

            if not image_data or len(image_data) < 100:
                self.send_error(400, "Invalid image data uploaded")
                return

            print(f"[Python API Server] Processing request for style: {style}")

            env = load_env()
            api_key = env.get("OPENAI_API_KEY", "").strip()

            # 1. Fallback to mock if API key is missing
            if not api_key or api_key == "YOUR_OPENAI_API_KEY":
                print("[Python API Server] OPENAI_API_KEY is not set. Executing Mock pipeline...")
                time.sleep(2.5)
                mock_filename = f"{style}.png"
                mock_file_path = os.path.join(MOCK_DIR, mock_filename)
                unique_name = f"gen_{int(time.time() * 1000)}_{random.randint(100, 999)}.png"
                target_path = os.path.join(GEN_DIR, unique_name)
                
                if os.path.exists(mock_file_path):
                    shutil.copyfile(mock_file_path, target_path)
                    host = self.headers.get('Host', 'localhost:3000')
                    output_url = f"http://{host}/generations/{unique_name}"
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(f'{{"success":true,"outputImageURL":"{output_url}"}}'.encode('utf-8'))
                    return
                else:
                    self.send_error(500, f"Mock asset '{style}.png' not found in public/mock/")
                    return

            # 2. Real API Integration Pipeline
            print("[Python API Server] Executing real OpenAI API pipeline...")
            
            # A. Vision step: Get detailed description from GPT-4o
            base64_image = base64.b64encode(image_data).decode('utf-8')
            
            vision_url = "https://api.openai.com/v1/chat/completions"
            vision_headers = {
                "Content-Type": "application/json",
                "Authorization": f"Bearer {api_key}"
            }
            vision_payload = {
                "model": "gpt-4o",
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {
                                "type": "text",
                                "text": "Analyze this image and describe the main subjects, layout, objects, colors, and composition in detail. Keep the description under 100 words. Focus strictly on content details, ignoring any artistic style or filters."
                            },
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/jpeg;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                "max_tokens": 150
            }
            
            print("[Python API Server] Querying GPT-4o vision to analyze the image...")
            req_vision = urllib.request.Request(
                vision_url, 
                data=json.dumps(vision_payload).encode('utf-8'), 
                headers=vision_headers
            )
            
            with urllib.request.urlopen(req_vision) as response:
                res_data = json.loads(response.read().decode('utf-8'))
                description = res_data["choices"][0]["message"]["content"].strip()
            
            print(f"[Python API Server] GPT-4o description: '{description}'")

            # B. Generate Step: Send style prompt + description to DALL-E 3
            style_prompt = STYLE_PROMPTS.get(style, STYLE_PROMPTS["sketchbook"])
            final_prompt = f"{style_prompt}\n\nHere is the composition detail of the subjects/scene to draw: {description}"
            
            dalle_url = "https://api.openai.com/v1/images/generations"
            dalle_payload = {
                "model": "dalle-3",
                "prompt": final_prompt,
                "n": 1,
                "size": "1024x1024",
                "quality": "standard"
            }
            
            print("[Python API Server] Querying DALL-E 3 to generate styled artwork...")
            req_dalle = urllib.request.Request(
                dalle_url, 
                data=json.dumps(dalle_payload).encode('utf-8'), 
                headers=vision_headers
            )
            
            with urllib.request.urlopen(req_dalle) as response:
                res_data = json.loads(response.read().decode('utf-8'))
                external_url = res_data["data"][0]["url"]
            
            print(f"[Python API Server] DALL-E 3 generated image URL: {external_url}")

            # C. Save step: Download generated image
            unique_name = f"gen_{int(time.time() * 1000)}_{random.randint(100, 999)}.png"
            target_path = os.path.join(GEN_DIR, unique_name)
            
            print(f"[Python API Server] Downloading stylized image to local storage: {target_path}")
            urllib.request.urlretrieve(external_url, target_path)
            
            host = self.headers.get('Host', 'localhost:3000')
            output_url = f"http://{host}/generations/{unique_name}"
            
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(f'{{"success":true,"outputImageURL":"{output_url}"}}'.encode('utf-8'))
            print(f"[Python API Server] Success! URL: {output_url}")

        except Exception as e:
            print(f"[Python API Server] Error: {e}. Falling back to Mock Mode...")
            try:
                mock_filename = f"{style}.png"
                mock_file_path = os.path.join(MOCK_DIR, mock_filename)
                unique_name = f"gen_{int(time.time() * 1000)}_{random.randint(100, 999)}.png"
                target_path = os.path.join(GEN_DIR, unique_name)
                
                if os.path.exists(mock_file_path):
                    shutil.copyfile(mock_file_path, target_path)
                    host = self.headers.get('Host', 'localhost:3000')
                    output_url = f"http://{host}/generations/{unique_name}"
                    
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Access-Control-Allow-Origin", "*")
                    self.end_headers()
                    self.wfile.write(f'{{"success":true,"outputImageURL":"{output_url}"}}'.encode('utf-8'))
                    print(f"[Python API Server] Success (Fallback Mode)! URL: {output_url}")
                    return
            except Exception as fallback_err:
                print(f"[Python API Server] Fallback logic failed: {fallback_err}")

            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            err_msg = str(e).replace('"', '\\"')
            self.wfile.write(f'{{"error":"{err_msg}"}}'.encode('utf-8'))

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

def run(port=3000):
    server_address = ('0.0.0.0', port)
    httpd = HTTPServer(server_address, CreateOBackendHandler)
    print(f"===============================================================")
    print(f"🐍 CreateO Python API Server running on http://localhost:{port}")
    print(f"📂 Serving static files from {PUBLIC_DIR}")
    print(f"🧪 Calls real GPT-4o vision + DALL-E 3 using OPENAI_API_KEY")
    print(f"===============================================================")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down server...")
        httpd.server_close()

if __name__ == "__main__":
    run()
