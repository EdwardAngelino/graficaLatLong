using Statistics


@time df2 = CSV.read("VV_TCR.csv", DataFrame, threaded=true, copycols=false, ignoreemptylines=true )
Arrow.write("VV_TCR.arrow", df2)

@time tbl = Arrow.Table("VV_TCR.arrow")
df = DataFrame(tbl)

df_2036 = filter(row -> endswith(strip(row.FECHA), "2036"), df)

df_2036[:, :carga_relativa] = abs.(df_2036.V_TCR_MW ./ df_2036.CAPCIP_MW)

g = groupby(df_2036, :COD_CRE)

df_stats_lineas = combine(g) do subdf
    min_carga  = minimum(subdf.carga_relativa)
    q1_carga   = quantile(subdf.carga_relativa, 0.25)
    mean_carga = mean(subdf.carga_relativa)
    std_carga  = std(subdf.carga_relativa)
    q3_carga   = quantile(subdf.carga_relativa, 0.75)
    max_carga  = maximum(subdf.carga_relativa)
    (; min_carga, q1_carga, mean_carga, std_carga, q3_carga, max_carga)
end

sort!(df_stats_lineas, :mean_carga, rev=true)

CSV.write("estadisticas_carga_lineas_2036_ordenadas.csv", df_stats_lineas)