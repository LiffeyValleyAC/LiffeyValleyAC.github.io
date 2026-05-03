import re

# Leer archivo
with open(r"c:\LiffeyValleyAC.github.io\_albums\2026-03-08-avondale-cup-2026.md", "r", encoding="utf-8") as f:
    content = f.read()

# Patrón para reemplazar rutas de thumbnail
# thumbnail: /assets/images/galleryimgs/avondale2026/FILENAME.jpg
# → thumbnail: /assets/images/galleryimgs/avondale2026/thumbs/FILENAME_thumb.jpg

def replace_thumbnail(match):
    path = match.group(1)
    filename = match.group(2)
    ext = match.group(3)
    
    # Crear nombre de thumbnail
    name = filename
    thumb_filename = name + "_thumb.jpg"
    
    new_path = f"/assets/images/galleryimgs/avondale2026/thumbs/{thumb_filename}"
    return f"thumbnail: {new_path}"

# Reemplazar cover también
content = re.sub(
    r'cover: /assets/images/galleryimgs/avondale2026/([^/]+\.jpg)',
    lambda m: f"cover: /assets/images/galleryimgs/avondale2026/thumbs/{m.group(1).replace('.jpg', '_thumb.jpg')}",
    content
)

# Reemplazar thumbnails
content = re.sub(
    r'thumbnail: /assets/images/galleryimgs/avondale2026/([^/]+\.jpg)',
    lambda m: f"thumbnail: /assets/images/galleryimgs/avondale2026/thumbs/{m.group(1).replace('.jpg', '_thumb.jpg')}",
    content
)

# Guardar archivo
with open(r"c:\LiffeyValleyAC.github.io\_albums\2026-03-08-avondale-cup-2026.md", "w", encoding="utf-8") as f:
    f.write(content)

print("Archivo actualizado correctamente")
print("Cover y todas las miniaturas apuntan ahora a la carpeta thumbs/")
