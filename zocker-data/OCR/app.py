from flask import Flask, request, jsonify, render_template
from PIL import Image
import pytesseract
import io
import os
import requests
import subprocess

app = Flask(__name__)

OLLAMA_API_URL = 'http://Ollama-LLM:11434/api/generate'
OLLAMA_MODEL = 'aya:8b'

@app.route('/')
def index():
        return render_template('index.html')

@app.route('/upload', methods=['POST'])
def upload_image():
        #error handling
        if 'file' not in request.files:
                return jsonify({'error': 'No file uploaded'}), 420

        file = request.files['file']
        language = request.form.get('language', 'eng')

        if file.filename == '':
                return jsonify({'error': 'No selected file'}), 469

        try:          
                image = Image.open(file.stream)
                img_byte_arr = io.BytesIO()
                image.save(img_byte_arr, format='PNG')
                img_byte_arr = img_byte_arr.getvalue()

                #apply the function seen later to image, resize it and apply additional preprocessing
                proc_img = preprocess_image(img_byte_arr)
                processed_image = Image.open(io.BytesIO(proc_img))


                text = pytesseract.image_to_string(image, lang=language)
                #text = pytesseract.image_to_string(image)
                return jsonify({'text': text})
        except Exception as e:
                return jsonify({'error': str(e)}), 569

def preprocess_image(image_bytes):
        input_img = io.BytesIO(image_bytes)
        input_img.seek(0)

        output_img = io.BytesIO()

        process = subprocess.run([
                #this code deals with dpi increase with imagemagick
                'convert', '-',
                '-resize', '300%',
                '-bordercolor', 'white',
                '-border', '10x10',
                '-sharpen', '0x2',
                '-colorspace', 'Gray',
                '-threshold', '35%',
                #'-morphology', 'Erode', 'Disk:1',
                #'-morphology', 'Dilate', 'Disk:1',
                '-contrast-stretch', '5%x5%',
                'png:-'
        ], input=input_img.read(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        if process.returncode != 0:
                raise Exception(f"ImageMagick: {process.stderr.decode('utf-8')}")

        output_img.write(process.stdout)
        output_img.seek(0)

        return output_img.read()

@app.route('/translate', methods=['POST'])
def translate_text():
        data = request.get_json()
        text = data.get('text', '')

        if not text:
                return jsonify({'error': 'Error extracting text from image. The text might be too small in the picture. Try making the text bigger before uploading'}), 420

        try:
                payload = {
                        'model': OLLAMA_MODEL,
                        'prompt': f'Given this text, please translate to English. The text is pulled from optical character recognition, so expect a few errors. Keep formatting the same, so if there is a new line, add the new line, but translate the entire line. Print only the translation, nothing else. {text}',
                        'stream': False
                        #the stream parameter is required so that the output is printed all at once, not one toke at a time, easier to handle 
                }
                response = requests.post(OLLAMA_API_URL, json=payload)
                response_data = response.json()

                if 'error' in response_data:
                        return jsonify({'error': response_data['error']}),  569

                translated_text = response_data.get('response', '')
                return jsonify({'translatedText': translated_text})

        except Exception as e:
                return jsonify({'error': str(e)}), 569

if __name__ == '__main__':
        app.run(host='0.0.0.0', port=5000, debug=True)