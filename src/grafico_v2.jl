using PlotlyJS, HTTP, JSON, DataFrames, CSV, WebIO

println("Cargando barras y líneas...")

# --- Leer archivos ---
dfBarras = CSV.read("Barras.csv", DataFrame)
dfLineas = CSV.read("Lineas.csv", DataFrame)

# --- Unir coordenadas de origen y destino ---
dfLineas = leftjoin(dfLineas, dfBarras, on = :Origen => :codigo, makeunique=true)
rename!(dfLineas, Dict(:latitud => :OrigenLat, :longitud => :OrigenLon))
dfLineas = leftjoin(dfLineas, dfBarras, on = :Destino => :codigo, makeunique=true)
rename!(dfLineas, Dict(:latitud => :DestinoLat, :longitud => :DestinoLon))

# --- Filtrar solo filas con coordenadas completas ---
dfLineas_filtrado = filter(row -> !ismissing(row.OrigenLat) &&
                                  !ismissing(row.OrigenLon) &&
                                  !ismissing(row.DestinoLat) &&
                                  !ismissing(row.DestinoLon), dfLineas)

# --- Filtrar barras que participan en alguna línea ---
codigos_validos = unique(vcat(dfLineas_filtrado.Origen, dfLineas_filtrado.Destino))
dfBarras_filtrado = filter(row -> row.codigo in codigos_validos, dfBarras)

println("Formando información gráfica...")

# --- Puntos de barras ---
puntos = scattermapbox(
    lat = dfBarras_filtrado.latitud,
    lon = dfBarras_filtrado.longitud,
    mode = "markers+text",
    text = dfBarras_filtrado.nombre,
    marker = attr(size=8, color="#756bb1"),
    name = "Barras"
)

# --- Función para crear trazas de líneas según tensiones seleccionadas ---
function generar_trazas(tensiones_seleccionadas)
    lineas_traces = []

    for row in eachrow(dfLineas_filtrado)
        if row.tension ∉ tensiones_seleccionadas
            continue
        end

        color_linea = if row.tension == 500.0
            "red"
        elseif row.tension == 220.0
            "blue"
        elseif row.tension == 138.0
            "green"
        else
            "gray"
        end

        ancho = row.proy == 1 ? 1 : 3
        opac  = row.proy == 1 ? 0.3 : 1.0

        push!(lineas_traces, scattermapbox(
            lat = [row.OrigenLat, row.DestinoLat],
            lon = [row.OrigenLon, row.DestinoLon],
            mode = "lines",
            line = attr(color=color_linea, width=ancho),
            opacity = opac,
            hovertext = string(row.COD_CIR, " (", row.Km, " km)"),
            hoverinfo = "text",
            showlegend = false
        ))
    end

    return lineas_traces
end

# --- Leyenda dummy ---
leyenda_traces = [
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="red", width=4), name="500 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="blue", width=4), name="220 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="green", width=4), name="138 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="gray", width=4), name="<100 kV")
]

# --- Layout ---
layout = Layout(
    title = "Mapa SEIN — Filtro múltiple por tensión",
    width = 1200,
    height = 900,
    showlegend = true,
    mapbox = attr(style="carto-positron", center=attr(lat=-10, lon=-77), zoom=4)
)

# --- Crear selector múltiple ---
tensiones = sort(unique(dfLineas_filtrado.tension))
dropdown = WebIO.node(:select, Dict(:multiple => true, :size => length(tensiones))) do
    [WebIO.node(:option, Dict(:value => string(t)), string(t, " kV")) for t in tensiones]
end

# --- Inicializar gráfico con todas las tensiones ---
fig = Plot([generar_trazas(tensiones)...; puntos; leyenda_traces...], layout)

# --- Conectar evento del dropdown ---
on(dropdown["value"]) do seleccion
    seleccion_float = parse.(Float64, seleccion)
    nuevas_trazas = [generar_trazas(seleccion_float)...; puntos; leyenda_traces...]
    relayout!(fig, data = nuevas_trazas)
end

# --- Mostrar ---
display(VBox(dropdown, fig))
