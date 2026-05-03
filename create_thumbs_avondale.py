from PIL import Image
import os
import glob

source_dir = r"c:\LiffeyValleyAC.github.io\assets\images\galleryimgs\avondale2026"
thumb_dir = os.path.join(source_dir, "thumbs")

os.makedirs(thumb_dir, exist_ok=True)

extensions = ['*.jpg', '*.jpeg', '*.JPG', '*.JPEG', '*.png', '*.PNG']
files = []
for ext in extensions:
    files.extend(glob.glob(os.path.join(source_dir, ext)))

files = [f for f in files if 'thumbs' not in f.lower()]
print(f"Procesando {len(files)} imagenes...")

for filepath in files:
    filename = os.path.basename(filepath)
    name, ext = os.path.splitext(filename)
    thumb_name = name + "_thumb.jpg"
    thumb_path = os.path.join(thumb_dir, thumb_name)
    
    try:
        with Image.open(filepath) as img:
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            img.thumbnail((300, 300), Image.Resampling.LANCZOS)
            img.save(thumb_path, "JPEG", quality=75, optimize=True)
            print(f"OK: {thumb_name}")
    except Exception as e:
        print(f"ERROR: {filename}: {e}")

print(f"\nThumbnails creados en: {thumb_dir}")
print(f"Total: {len([f for f in os.listdir(thumb_dir) if f.endswith('_thumb.jpg')])} miniaturas")
