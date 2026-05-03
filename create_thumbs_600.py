from PIL import Image
import os
import glob
import sys

def create_thumbnails(source_dir, size=600):
    thumb_dir = os.path.join(source_dir, "thumbs")
    
    # Eliminar thumbs existentes
    if os.path.exists(thumb_dir):
        for f in os.listdir(thumb_dir):
            if f.endswith('_thumb.jpg'):
                os.remove(os.path.join(thumb_dir, f))
        print(f"Thumbs anteriores eliminados de {thumb_dir}")
    
    os.makedirs(thumb_dir, exist_ok=True)
    
    extensions = ['*.jpg', '*.jpeg', '*.JPG', '*.JPEG', '*.png', '*.PNG']
    files = []
    for ext in extensions:
        files.extend(glob.glob(os.path.join(source_dir, ext)))
    
    files = [f for f in files if 'thumbs' not in f.lower()]
    print(f"Procesando {len(files)} imagenes a {size}px...")
    
    for filepath in files:
        filename = os.path.basename(filepath)
        name, ext = os.path.splitext(filename)
        thumb_name = name + "_thumb.jpg"
        thumb_path = os.path.join(thumb_dir, thumb_name)
        
        try:
            with Image.open(filepath) as img:
                if img.mode in ('RGBA', 'P'):
                    img = img.convert('RGB')
                # Usar LANCZOS para mejor calidad
                img.thumbnail((size, size), Image.Resampling.LANCZOS)
                img.save(thumb_path, "JPEG", quality=85, optimize=True)
                print(f"OK: {thumb_name} ({img.size[0]}x{img.size[1]})")
        except Exception as e:
            print(f"ERROR: {filename}: {e}")
    
    thumb_count = len([f for f in os.listdir(thumb_dir) if f.endswith('_thumb.jpg')])
    print(f"\nThumbnails creados: {thumb_count}")
    return thumb_count

if __name__ == "__main__":
    # Procesar National Road Relays
    print("="*50)
    print("NATIONAL ROAD RELAYS")
    print("="*50)
    relays_dir = r"c:\LiffeyValleyAC.github.io\assets\images\galleryimgs\2026-04-26_national_road_relays"
    create_thumbnails(relays_dir, 600)
    
    # Procesar Avondale Cup
    print("\n" + "="*50)
    print("AVONDALE CUP")
    print("="*50)
    avondale_dir = r"c:\LiffeyValleyAC.github.io\assets\images\galleryimgs\avondale2026"
    create_thumbnails(avondale_dir, 600)
    
    print("\n✓ Miniaturas de 600px generadas correctamente")
