package settings

import "core:testing"

@(test)
llm_feature_choices_include_charger_diagnostics :: proc(t:^testing.T) {
    for feature in LLM_Feature {
        parsed,ok:=llm_feature_from_storage_id(llm_feature_storage_id(feature))
        testing.expect(t,ok && parsed==feature)
    }
    configs:=`[{"id":"config","model":"fixture/model","provider":null,"label":null,"is_active":true}]`
    selections:=`[{"feature":"charger_diagnostics","config_id":"config"}]`
    snapshot,ok:=llm_snapshot_decode(transmute([]u8)configs,transmute([]u8)selections,context.temp_allocator)
    testing.expect(t,ok && snapshot.feature_selection_present[.Charger_Diagnostics])
    testing.expect_value(t,snapshot.feature_selections[.Charger_Diagnostics].config_id,"config")
    state:State
    testing.expect(t,state_replace_llm_configs(&state,snapshot.configs[:]))
    testing.expect(t,state_llm_config_for_feature(&state,.Charger_Diagnostics)==nil)
    testing.expect(t,state_set_feature_selection(&state,.Charger_Diagnostics,"config"))
    testing.expect_value(t,state_llm_config_for_feature(&state,.Charger_Diagnostics).model,"fixture/model")
}
