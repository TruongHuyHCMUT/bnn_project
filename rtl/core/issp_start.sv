module issp_start (
    output logic source
);

    altsource_probe #(
        .sld_auto_instance_index("YES"),
        .sld_instance_index(0),
        .instance_id("STRT"), 
        .probe_width(0),
        .source_width(1),
        .source_initial_value("0"),
        .enable_metastability("NO")
    ) altsource_probe_component (
        .source (source)
    );
endmodule