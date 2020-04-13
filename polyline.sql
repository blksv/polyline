create or replace function decode_polyline_values(polyline text)
returns setof bigint as
$$
declare
  c char;
  cur bigint := 0;
  v int := 0;
  i int := 0;
  final bool := false;
begin
  if polyline is null or polyline = '' then
    return;
  end if;
  foreach c in array string_to_array(polyline, null) loop
    v = ascii(c) - 63;
    final = ((v & 32) = 0);
    v = v & 31;
    cur = cur | (v::bigint << (i * 5));
    i = i + 1;
    if final then
      if cur & 1 = 1 then
        cur = ~cur;
      end if;
      return next cur >> 1;
      i = 0;
      cur = 0;
    end if;
  end loop;
end
$$ LANGUAGE plpgsql;

create or replace function decode_polyline(polyline text)
returns table (lat real, lon real) as
$$
declare
  prev_lat real := 0;
  prev_lon real := 0;
  vals bigint[];
  i int;
begin
  vals = (select array_agg(v) from decode_polyline_values(polyline) v);
  if vals is null then
    return;
  end if;

  for i in 1..array_length(vals,1) by 2 loop
    prev_lat = prev_lat + vals[i]/1e5;
    prev_lon = prev_lon + vals[i+1]/1e5;
    lat = prev_lat;
    lon = prev_lon;
    return next;
  end loop;
end
$$ LANGUAGE plpgsql;


create or replace function encode_polyline_value(val bigint)
returns text as
$$
declare
  ret text := '';
begin
  val = val << 1;
  if val < 0 then
    val = ~val;
  end if;

  while val >= 32 loop
    ret = ret || chr((((val & 31) | 32) + 63)::int);
    val = val >> 5;
  end loop;
  ret = ret || chr((val + 63)::int);
  return ret;
end
$$ LANGUAGE plpgsql;


create or replace function encode_polyline(vals real[])
returns text as
$$
declare
  ret text := '';
  plat real := 0;
  plon real := 0;
  dlat bigint := 0;
  dlon bigint := 0;
begin
  for i in 1..array_length(vals,1) by 2 loop
    dlat = round((vals[i] - plat) * 1e5);
    dlon = round((vals[i+1] - plon) * 1e5);
    ret = ret || encode_polyline_value(dlat) || encode_polyline_value(dlon);
    plat = plat + dlat/1e5;
    plon = plon + dlon/1e5;
  end loop;
  return ret;
end
$$ LANGUAGE plpgsql;