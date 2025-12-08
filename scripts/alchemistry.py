import re
import argparse

parser = argparse.ArgumentParser()

parser.add_argument("input_yaml", help="yaml of input ingredients (produced by delta_plugin)")
cmd_args = parser.parse_args()

yaml_in_path = cmd_args.input_yaml
yaml_out_path = "./alchemistry_ingredients.yaml"
lua_out_path = "./alchemistry_ingredients.lua"

yaml_in = open(yaml_in_path).read()


file_header = re.search(r'^.+\nrecords:', yaml_in, re.DOTALL)
if not file_header:
   print("Cannot parse the plugin's header from the input. Aborting...")


rx_effects = re.compile(r'\n\s+- effect:\s+(?P<type>\w+)(?:\n\s+attribute:\s+(?P<attribute>\w+))?(?:\n\s+skill:\s+(?P<skill>\w+))?', re.DOTALL)
rx_effect_type = re.compile(r'\n\s+- effect:\s+(?P<type>\w+)', re.DOTALL)

rx_header_name    = re.compile(r'\n\s+name:\s+(.+?[^\s])\s*?\n', re.DOTALL)
rx_header_model   = re.compile(r'\n\s+model:\s+(.+?[^\s])\s*?\n', re.DOTALL)
rx_header_icon    = re.compile(r'\n\s+icon:\s+(.+?[^\s])\s*?\n', re.DOTALL)
rx_header_weight  = re.compile(r'\n\s+weight:\s+(.+?[^\s])\s*?\n', re.DOTALL)
rx_header_value   = re.compile(r'\n\s+value:\s+(.*?[^\s])\s*?\n', re.DOTALL)




def write_NMIWV(record_id, header):
    def write_header_value(rx, field_name, is_path):
        value = rx.search(header)
        if not value:
            print(f"Warning: ingredient {record_id} doesn't have a {field_name}")
        else:
            value = value.group(1)
            if is_path:
                value = value.lower().replace("\\\\", "/")

            yaml_out.write(f"    {field_name}: {value}\n")

    write_header_value(rx_header_name,   "name",   False)
    write_header_value(rx_header_model,  "model",  True)
    write_header_value(rx_header_icon,   "icon",   True)
    write_header_value(rx_header_weight, "weight", False)
    write_header_value(rx_header_value,  "value",  False)



def write_ingredient(rx_iter):
    record_id = rx_iter.group("record_id")
    header = rx_iter.group("header")
    tail = rx_iter.group("tail")

    # Esp
    yaml_out.write(f'  "Ingredient::{record_id}":\n')
    yaml_out.write('    type: Ingredient\n')
    write_NMIWV(record_id, header)
    yaml_out.write('    effects: []\n')

    if tail:
        yaml_out.write(tail)
        yaml_out.write("\n")

    # Lua
    lua_out.write(f'  ["{record_id}"] = {{\n')

    for (eff, attr, skill) in rx_effects.findall(rx_iter.group("effects")):
        if attr or skill:
            lua_out.write(f'    {{ "{eff}" ')
            if attr:
                lua_out.write(f', "{attr}" ')
            elif skill:
                lua_out.write(f', "{skill}" ')

            lua_out.write('},\n')
        else:
            lua_out.write(f'    "{eff}",\n')

    lua_out.write('  },\n')



def write_potion(rx_iter):
    record_id = rx_iter.group("record_id")
    header = rx_iter.group("header")
    tail = rx_iter.group("tail")

    yaml_out.write(f'  "Ingredient::{record_id}": ~\n')

    yaml_out.write(f'  "Potion::{record_id}":\n')
    yaml_out.write('    type: Potion\n')
    write_NMIWV(record_id, header)
    yaml_out.write('    autocalc: false\n'
                   '    effects:\n'
                   '      - effect_type: RestoreFatigue\n'
                   '        range: SelfType\n'
                   '        area: 0\n'
                   '        duration: 120\n'
                   '        min_magnitude: 1\n'
                   '        max_magnitude: 1\n'
    )

    if tail:
        yaml_out.write(tail)
        yaml_out.write("\n")


# return True if ingredient has only one effect which is RestoreFatigue
def is_potion(str_effects):
    had_one = False
    for eff in rx_effect_type.findall(str_effects):
        if eff != "RestoreFatigue" or had_one:
            return False
        had_one = True

    return had_one






yaml_out = open(yaml_out_path, mode = "w", buffering = 64*1024)
yaml_out.write(file_header.group())
yaml_out.write("\n")

lua_out = open(lua_out_path, mode = "w", buffering = 64*1024)
lua_out.write("return {\n")

rx_iter_ingredients = re.finditer(
    r'\n(?P<header>\s+"Ingredient::(?P<record_id>[^"]+)":\s*\n.+?\n(?P<indent>\s+)effects:)\s*'
    r'(?P<effects>\[\]|\n.+?)'
    r'(\n(?P<tail>(?P=indent)\w.+?))?(?=$|\n\s+"Ingredient::)',
    yaml_in, re.DOTALL)

for i in rx_iter_ingredients:
    if is_potion(i.group("effects")):
        write_potion(i)
    else:
        write_ingredient(i)

yaml_out.close()

lua_out.write("}\n")
lua_out.close()
