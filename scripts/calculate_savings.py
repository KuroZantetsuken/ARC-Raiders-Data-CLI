import json
import os
import glob
import shutil

# Paths relative to the project root
SOURCE_DIR = os.path.join('arcraiders-data', 'items')
DEST_DIR = os.path.join('data', 'items')

def load_items(source_dir):
    items = {}
    if not os.path.exists(source_dir):
        print(f"Error: Source directory {source_dir} does not exist.")
        return items

    files = glob.glob(os.path.join(source_dir, '*.json'))
    for file_path in files:
        with open(file_path, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
                if 'id' in data:
                    items[data['id']] = data
                else:
                    print(f"Warning: No 'id' in {file_path}")
            except json.JSONDecodeError as e:
                print(f"Error decoding {file_path}: {e}")
    return items

def calculate_savings(item, items_map):
    if 'recipe' not in item:
        return None
    
    recipe = item['recipe']
    if not recipe:
        return None

    # Calculate Ingredient Space
    ingredient_space = 0.0
    for ingredient_id, quantity in recipe.items():
        if ingredient_id not in items_map:
            # Try to handle case mismatch or fallback?
            # For now, just log warning.
            # print(f"Warning: Ingredient '{ingredient_id}' for item '{item['id']}' not found in source data.")
            return None 
        
        ingredient = items_map[ingredient_id]
        stack_size = ingredient.get('stackSize', 1)
        # Avoid division by zero
        if stack_size <= 0:
            stack_size = 1
        
        ingredient_space += quantity / stack_size

    # Calculate Target Space
    craft_quantity = item.get('craftQuantity', 1)
    target_stack_size = item.get('stackSize', 1)
    if target_stack_size <= 0:
        target_stack_size = 1
        
    target_space = craft_quantity / target_stack_size

    savings = ingredient_space - target_space
    return savings

def main():
    # Clear and recreate destination directory
    if os.path.exists(DEST_DIR):
        print(f"Clearing destination directory: {DEST_DIR}")
        shutil.rmtree(DEST_DIR)
    os.makedirs(DEST_DIR)

    # 1. Load all items for lookup
    print(f"Loading items from {SOURCE_DIR}...")
    items_map = load_items(SOURCE_DIR)
    print(f"Loaded {len(items_map)} items.")

    if not items_map:
        print("No items found. Exiting.")
        return

    # 2. Process items
    print("Calculating savings and writing files...")
    processed_count = 0
    calculated_count = 0
    
    files = glob.glob(os.path.join(SOURCE_DIR, '*.json'))
    for file_path in files:
        filename = os.path.basename(file_path)
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"Skipping {filename}: {e}")
            continue
        
        # Calculate savings using the pre-loaded map
        if 'id' in data:
            savings = calculate_savings(data, items_map)
            if savings is not None:
                data['stashSavings'] = savings
                calculated_count += 1
        
        # Write to destination
        dest_path = os.path.join(DEST_DIR, filename)
        with open(dest_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
            
        processed_count += 1

    print(f"Processed {processed_count} files. Calculated savings for {calculated_count} items.")
    print(f"Output saved to {DEST_DIR}")

if __name__ == "__main__":
    main()
