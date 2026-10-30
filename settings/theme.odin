package settings

THEME_CATALOG := [15]Theme_Definition {
	{.Light, "light", "Delta Light", "Delta", .Light, 0xffffffff, 0x111827ff, 0xe7edf4ff, 0x267267ff},
	{.Dark, "dark", "Delta Dark", "Delta", .Dark, 0x020817ff, 0xd3dce8ff, 0x1e293bff, 0x80cbb0ff},
	{.Gruvbox_Light, "gruvbox-light", "Gruvbox Light", "Gruvbox", .Light, 0xfbf1c7ff, 0x3c3836ff, 0xebdbb2ff, 0xb57614ff},
	{.Gruvbox_Dark, "gruvbox-dark", "Gruvbox Dark", "Gruvbox", .Dark, 0x282828ff, 0xebdbb2ff, 0x3c3836ff, 0xd79921ff},
	{.Catppuccin_Latte, "catppuccin-latte", "Catppuccin Latte", "Catppuccin", .Light, 0xeff1f5ff, 0x4c4f69ff, 0xdce0e8ff, 0x8839efff},
	{.Catppuccin_Mocha, "catppuccin-mocha", "Catppuccin Mocha", "Catppuccin", .Dark, 0x1e1e2eff, 0xcdd6f4ff, 0x313244ff, 0xcba6f7ff},
	{.Dracula, "dracula", "Dracula", "Dracula", .Dark, 0x282a36ff, 0xf8f8f2ff, 0x44475aff, 0xbd93f9ff},
	{.Nord, "nord", "Nord", "Nord", .Dark, 0x2e3440ff, 0xeceff4ff, 0x3b4252ff, 0x88c0d0ff},
	{.Tokyo_Night, "tokyo-night", "Tokyo Night", "Tokyo Night", .Dark, 0x1a1b26ff, 0xc0caf5ff, 0x292e42ff, 0x7aa2f7ff},
	{.One_Dark, "one-dark", "One Dark", "One", .Dark, 0x282c34ff, 0xabb2bfff, 0x3e4451ff, 0x61afefff},
	{.Solarized_Light, "solarized-light", "Solarized Light", "Solarized", .Light, 0xfdf6e3ff, 0x586e75ff, 0xeee8d5ff, 0x268bd2ff},
	{.Solarized_Dark, "solarized-dark", "Solarized Dark", "Solarized", .Dark, 0x002b36ff, 0x93a1a1ff, 0x073642ff, 0x2aa198ff},
	{.Monokai, "monokai", "Monokai", "Monokai", .Dark, 0x272822ff, 0xf8f8f2ff, 0x3e3d32ff, 0xa6e22eff},
	{.Github_Light, "github-light", "GitHub Light", "GitHub", .Light, 0xffffffff, 0x1f2328ff, 0xf6f8faff, 0x0969daff},
	{.Github_Dark, "github-dark", "GitHub Dark", "GitHub", .Dark, 0x0d1117ff, 0xe6edf3ff, 0x21262dff, 0x2f81f7ff},
}

theme_definition :: proc(theme: Theme) -> ^Theme_Definition {
	return &THEME_CATALOG[int(theme)]
}

theme_from_storage_id :: proc(value: string) -> Theme {
	for definition in THEME_CATALOG {
		if definition.storage_id == value { return definition.id }
	}
	return .Light
}

root_font_pixels_clamp :: proc(value: int) -> int {
	return min(max(value, 12), 24)
}
