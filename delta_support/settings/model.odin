package settings

MAX_LLM_CONFIGS :: 64
MAX_DIAGNOSTIC_VALUES :: 256

Tab :: enum u8 {
	General,
	Paths,
	Authentication,
	Data_Reload,
	Administration,
	Diagnostics,
	Charge_Log_Inventory,
	Plug_Log_Inventory,
	OCPP_Log_Inventory,
}

Theme :: enum u8 {
	Light,
	Dark,
	Gruvbox_Light,
	Gruvbox_Dark,
	Catppuccin_Latte,
	Catppuccin_Mocha,
	Dracula,
	Nord,
	Tokyo_Night,
	One_Dark,
	Solarized_Light,
	Solarized_Dark,
	Monokai,
	Github_Light,
	Github_Dark,
}

Color_Scheme :: enum u8 {
	Light,
	Dark,
}

Theme_Definition :: struct {
	id:           Theme,
	storage_id:   string,
	label:        string,
	family:       string,
	color_scheme: Color_Scheme,
	background:   u32,
	foreground:   u32,
	surface:      u32,
	accent:       u32,
}

Charger_Default_Tab :: enum u8 {
	Diagnostics,
	Statistics,
	Detailed,
	Location,
	Plug_Logs,
	Sessions,
	Config,
	Config_History,
	Archived_Logs,
	Charger_Events,
	State_Machine,
	Teltonika_Config,
}

Service_Visits_Display_Mode :: enum u8 {
	List,
	Timeline,
}

LLM_Feature :: enum u8 {
	Email_Summarization,
	Case_Summarization,
	Location_Matching,
	Knowledge_Article_Generation,
	Charger_Diagnostics,
}

LLM_Config :: struct {
	id:         string,
	model:      string,
	providers:  []string,
	is_active:  bool,
	label:      string,
}

LLM_Feature_Selection :: struct {
	feature:   LLM_Feature,
	config_id: string,
}

Version_Config :: struct {
	id:           string,
	min_version:  string,
	latest_version: string,
	download_url: string,
	has_download_url: bool,
	updated_at:   string,
}

Path_Settings :: struct {
	report_output_folder:       string,
	log_files_cache_root:       string,
	prepare_for_l2_output_folder: string,
}

State :: struct {
	opened:                           bool,
	selected_tab:                     Tab,
	show_search_filters_for_debugging: bool,
	theme:                            Theme,
	root_font_pixels:                 int,
	search_scroll_speed_percent:      int,
	cabinet_default_tab:              Charger_Default_Tab,
	service_visits_display_mode:      Service_Visits_Display_Mode,
	paths:                            Path_Settings,
	active_role_override:             string,
	llm_configs:                      [MAX_LLM_CONFIGS]LLM_Config,
	llm_config_count:                 int,
	feature_selections:               [LLM_Feature]LLM_Feature_Selection,
	version_config:                   Version_Config,
	diagnostics_queues:               [MAX_DIAGNOSTIC_VALUES]string,
	diagnostics_queue_count:          int,
	diagnostics_owners:               [MAX_DIAGNOSTIC_VALUES]string,
	diagnostics_owner_count:          int,
	diagnostics_statuses:             [MAX_DIAGNOSTIC_VALUES]string,
	diagnostics_status_count:         int,
}

Persistence_Action_Kind :: enum u8 {
	None,
	Write_Device_Preferences,
	Write_Report_Output_File,
	Delete_Report_Output_File,
	Write_Log_Cache_File,
	Delete_Log_Cache_File,
	Upsert_Prepare_L2_Folder,
	Delete_Prepare_L2_Folder,
}

Persistence_Action :: struct {
	kind:  Persistence_Action_Kind,
	value: string,
}
