using PlotlyJS, HTTP, JSON, DataFrames, CSV, WebIO


println("Cargando barras y lineas...")
# --- Leer archivos ---
dfBarras = CSV.read("Barras.csv", DataFrame)
dfLineas = CSV.read("Lineas.csv", DataFrame)



# --- Unir coordenadas de origen ---
dfLineas = leftjoin(dfLineas, dfBarras, on = :Origen => :codigo, makeunique=true)
rename!(dfLineas, Dict(:latitud => :OrigenLat, :longitud => :OrigenLon))

# --- Unir coordenadas de destino ---
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

#display(dfLineas_filtrado)
println("Formando información gráfica...")

# --- Crear scatter de puntos ---
puntos = scattermapbox(
    lat = dfBarras_filtrado.latitud,
    lon = dfBarras_filtrado.longitud,
    mode = "markers+text",
    text = dfBarras_filtrado.nombre,
    marker = attr(size=8, color="#756bb1"),
    name = "Barras"
)

# --- Crear trazos de líneas ---
lineas_traces = []

# Tomar solo las xxx primeras líneas
#df_prueba = first(dfLineas_filtrado, 894)

for row in eachrow(dfLineas_filtrado)
	    # Asignar color según tensión
    color_linea = if row.tension == 500.0
        "red"
    elseif row.tension == 220.0
        "blue"
    elseif row.tension == 138.0
        "green"
    else
        "gray"
    end

    # Diferenciar líneas de proyecto
    ancho = row.proy == 1 ? 1 : 3       # más finas si son proyecto
    opac  = row.proy == 1 ? 0.3 : 1.0  # más transparentes si son proyecto

    if row.tension > 100.0
     push!(lineas_traces, scattermapbox(
        lat = [row.OrigenLat, row.DestinoLat],
        lon = [row.OrigenLon, row.DestinoLon],
        mode = "lines",
        line = attr(color=color_linea, width=ancho),
        opacity = opac,
        name = "",
        showlegend = false
     ))
    end

#=    # punto medio para mostrar el texto fijo km
    mid_lat = (row.OrigenLat + row.DestinoLat) / 2
    mid_lon = (row.OrigenLon + row.DestinoLon) / 2

    push!(lineas_traces, scattermapbox(
        lat = [mid_lat],
        lon = [mid_lon],
        mode = "text",
        text = [string(round(row.Km, digits=1), " km")],
        textfont = attr(size=10, color=color_linea),
        showlegend = false,
        name = "longitud"
    ))=#
end

# --- Trazas dummy para leyenda ---
leyenda_traces = [
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="red", width=4), name="500 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="blue", width=4), name="220 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="green", width=4), name="138 kV"),
    scattermapbox(lat=[NaN], lon=[NaN], mode="lines", line=attr(color="gray", width=4), name="<100 kV")
]

# --- Layout del mapa ---
layout = Layout(
    title = "Mapa SEIN",
    width = 1200,    # ancho en píxeles
    height = 900,    # alto en píxeles
    showlegend = true,
    mapbox = attr(
        style = "carto-positron", #open-street-map
        center = attr(lat=-10, lon=-77),
        zoom = 4
    )
)

println("Renderizando...")


# --- Graficar todos los trazos juntos ---


fig = plot([ lineas_traces...; puntos; leyenda_traces...], layout)
display(fig)


println("Presiona ENTER para cerrar...")
readline()    # evita que Julia termine inmediatamente
