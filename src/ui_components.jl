function make_synced_textfield(slider_widget, fwd=identity, inv=identity; digits::Int=2, mirror_slider_to_textfield::Bool=true)
	display_val = fwd(slider_widget.value[])
	tf = Bonito.TextField(string(round(display_val, digits=digits)))
	if mirror_slider_to_textfield
		on(slider_widget.value) do v
			new_val = string(round(fwd(v), digits=digits))
			tf.value[] == new_val && return
			tf.value[] = new_val
		end
	end
	on(tf.value) do v
		try
			typed = parse(Float64, strip(v))
			raw   = inv(typed)
			if slider_widget.value[] != raw
				slider_widget.value[] = raw
			end
		catch
		end
	end
	return tf
end

function slider_row(slider_widget, tf)
	Bonito.DOM.div(slider_widget, tf,
		style="display:flex; align-items:center; gap:8px;",
		class="slider-tf-wrap")
end

function build_event_table_dom(events_df::DataFrame; max_rows::Int=30)
	th_s = "padding:4px 6px; text-align:left; font-size:9px; font-weight:700; color:var(--accent2); border-bottom:1px solid var(--border); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:70px; text-transform:uppercase; letter-spacing:0.4px;"
	td_s = "padding:3px 6px; font-size:9px; color:var(--text1); border-bottom:1px solid var(--border); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:70px; font-family:monospace;"
	td_a = "padding:3px 6px; font-size:9px; color:var(--text1); border-bottom:1px solid var(--border); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:70px; font-family:monospace; background:rgba(88,166,255,0.08);"
	if isempty(events_df)
		return Bonito.DOM.div(
			Bonito.DOM.span("No events yet — run a simulation first.",
				style="font-size:10px; color:var(--text2); font-style:italic;"),
			style="padding:10px;")
	end
	display_cols = [n for n in names(events_df) if n != "metadata"]
	n_rows = min(nrow(events_df), max_rows)
	header_cells = [Bonito.DOM.th(col; style=th_s) for col in display_cols]
	header_row   = Bonito.DOM.tr(header_cells...)
	dom_rows = []
	for i in 1:n_rows
		row_style = i % 2 == 0 ? td_a : td_s
		cells = []
		for col in display_cols
			val = events_df[i, col]
			cell_content = if col == "event" && !ismissing(val)
				ev_str = string(val)
				color  = ev_str == "S" ? "#58a6ff" : (ev_str == "R" ? "#f78166" : "#3fb950")
				Bonito.DOM.td(Bonito.DOM.span(ev_str; style="color:$color; font-weight:700;"); style=row_style)
			elseif col == "latency" && !ismissing(val)
				Bonito.DOM.td(string(round(Float64(val), digits=1)); style=row_style)
			else
				Bonito.DOM.td(ismissing(val) ? "—" : string(val); style=row_style)
			end
			push!(cells, cell_content)
		end
		push!(dom_rows, Bonito.DOM.tr(cells...))
	end
	if nrow(events_df) > max_rows
		note_td = Bonito.DOM.td("… $(nrow(events_df) - max_rows) more rows not shown …";
			style="$td_s color:var(--text2); font-style:italic; text-align:center;")
		push!(dom_rows, Bonito.DOM.tr(note_td))
	end
	table = Bonito.DOM.table(
		Bonito.DOM.thead(header_row),
		Bonito.DOM.tbody(dom_rows...);
		style="border-collapse:collapse; width:100%; table-layout:fixed;")
	info = Bonito.DOM.div(
		"$(nrow(events_df)) events · $(length(display_cols)) columns";
		style="font-size:9px; color:var(--text2); text-align:right; margin-top:3px; padding-right:4px;")
	return Bonito.DOM.div(
		Bonito.DOM.div(table;
			style="overflow-x:auto; overflow-y:auto; max-height:200px; max-width:100%; border-radius:5px; border:1px solid var(--border); box-sizing:border-box;"),
		info;
		style="width:100%; max-width:100%; box-sizing:border-box; overflow:hidden;")
end
