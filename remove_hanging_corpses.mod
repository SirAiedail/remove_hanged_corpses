return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Remove Hanged Corpses` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("remove_hanging_corpses", {
			mod_script       = "scripts/mods/remove_hanging_corpses/remove_hanging_corpses",
			mod_data         = "scripts/mods/remove_hanging_corpses/remove_hanging_corpses_data",
			mod_localization = "scripts/mods/remove_hanging_corpses/remove_hanging_corpses_localization",
		})
	end,
	packages = {
		"resource_packages/remove_hanging_corpses/remove_hanging_corpses",
	},
}
