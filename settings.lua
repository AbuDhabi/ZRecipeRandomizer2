local presets = require "scripts.settings-presets"

local p = presets.get()

data:extend({
    {
        type = "string-setting",
        name = "z-randomizer-preset",
		order = "aa",
        setting_type = "startup",
        default_value = "INFO",
        allowed_values = p.localized_name
    },
    {
        type = "int-setting",
        name = "z-randomizer-seed",
		order = "ab",
        setting_type = "startup",
        default_value = 0,
        minimum_value = 0,
        maximum_value = 1099511627775,
    },
    {
        type = "string-setting",
        name = "z-randomizer-randomize-time",
		order = "ba",
        setting_type = "startup",
        default_value = "medium",
        allowed_values = {"none", "small", "medium", "large", "huge"},
    },
    {
        type = "string-setting",
        name = "z-randomizer-dependencies",
		order = "bb",
        setting_type = "startup",
        default_value = "branched",
        allowed_values = {"none", "linear", "branched"},
    },
    {
        type = "double-setting",
        name = "z-randomizer-resource-variance",
		order = "bc",
        setting_type = "startup",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 5,
    },
    {
        type = "double-setting",
        name = "z-randomizer-complexity-variance",
		order = "bd",
        setting_type = "startup",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 5,
    },
    {
        type = "double-setting",
        name = "z-randomizer-cost-variance",
		order = "be",
        setting_type = "startup",
        default_value = 2,
        minimum_value = 1,
        maximum_value = 5,
    },
    {
        type = "string-setting",
        name = "z-randomizer-hidden",
		order = "bz",
        setting_type = "startup",
        default_value = "calculate",
        allowed_values = {"ignore", "calculate", "randomize"}
    },
    {
        type = "string-setting",
        name = "z-randomizer-default-values",
		order = "ca",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.default_values
    },
    {
        type = "string-setting",
        name = "z-randomizer-not-random-resources",
		order = "cb",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.not_random_resources
    },
    {
        type = "string-setting",
        name = "z-randomizer-not-random-recipes",
		order = "da",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.not_random_recipes
    },
    {
        type = "string-setting",
        name = "z-randomizer-not-random-categories",
		order = "db",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.not_random_categories
    },
    {
        type = "string-setting",
        name = "z-randomizer-not-random-ingredients",
		order = "dd",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.not_random_ingredients
    },
    {
        type = "bool-setting",
        name = "z-randomizer-not-random-ore-processing",
		order = "de",
        setting_type = "startup",
        default_value = p.not_random_ore_processing
    },
    {
        type = "string-setting",
        name = "z-randomizer-forbidden-recipes",
		order = "fa",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.forbidden_recipes
    },
    {
        type = "string-setting",
        name = "z-randomizer-forbidden-categories",
		order = "fb",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.forbidden_categories
    },
    {
        type = "string-setting",
        name = "z-randomizer-forbidden-ingredients",
		order = "fc",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.forbidden_ingredients
    },
    {
        type = "string-setting",
        name = "z-randomizer-forbidden-results",
		order = "fd",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.forbidden_results
    },
    {
        type = "string-setting",
        name = "z-randomizer-starter-crafting",
		order = "ha",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.starter_crafting,
    },
    {
        type = "string-setting",
        name = "z-randomizer-prevent-duplicates",
		order = "hb",
        setting_type = "startup",
        allow_blank = true,
        default_value = p.prevent_duplicates,
    }
})