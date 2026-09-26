from PIL import Image, ImageDraw

def extract_flame_perfectly():
    img = Image.open("assets/icon_koyilandy.png").convert("RGBA")
    width, height = img.size
    
    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    
    # We want to completely exclude the narrow line at the bottom AND the top edge.
    # When top was 260, the flame tip was chopped off.
    # When top was 150, the top ring was included.
    # Let's set top to 190 to perfectly include the flame tip but exclude the top ring.
    draw.ellipse((270, 190, 750, 770), fill=255)
    
    flame_only = Image.new("RGBA", (width, height), (0,0,0,0))
    flame_only.paste(img, (0,0), mask)
    
    # Remove dark grey background pixels
    pixels = flame_only.load()
    min_x, max_x = width, 0
    min_y, max_y = height, 0
    
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a > 0:
                # If it's a dark background pixel (greyish), make it transparent
                if g > 50 and g > r + 10 and g > b + 10:
                    if x < min_x: min_x = x
                    if x > max_x: max_x = x
                    if y < min_y: min_y = y
                    if y > max_y: max_y = y
                else:
                    pixels[x, y] = (0, 0, 0, 0)
                    
    # Crop exactly to the flame
    if min_x < max_x and min_y < max_y:
        final_flame = flame_only.crop((min_x, min_y, max_x, max_y))
        
        # Resize to fill the adaptive icon safe area (max size ~800)
        max_size = 800
        w, h = final_flame.size
        ratio = min(max_size / w, max_size / h)
        new_w, new_h = int(w * ratio), int(h * ratio)
        
        final_flame = final_flame.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Paste into 1024x1024 transparent canvas
        new_img = Image.new("RGBA", (1024, 1024), (0,0,0,0))
        offset_x = (1024 - new_w) // 2
        offset_y = (1024 - new_h) // 2
        
        new_img.paste(final_flame, (offset_x, offset_y), final_flame)
        
        new_img.save("assets/icon_koyilandy_foreground.png")
        print(f"Successfully isolated the flame (Top cut at 190, Bottom cut at 770). Bounding box was {min_x},{min_y} to {max_x},{max_y}")
    else:
        print("Failed to isolate the flame.")

if __name__ == "__main__":
    extract_flame_perfectly()
