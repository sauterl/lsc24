using JSON, CSV, DataFrames, Statistics, DataFramesMeta, Query;

# Small utility which attaches metadata from LSC / CSV format to EXIF
#
# ## Prerequisites: 
# - Expects exiftool to be installed and callable
# - Julia, including the packages above
#
# ## Arguments
# METAFILE - Path to the metadata csv file
# IMAGES - Path to the root of the images. Expects either a folder of subfolders (one per month) of subfolders (one per day) of image files or all images flat
# DESTINATION - Path to the destination images will result in a folder of subfolders 


metafile = ARGS[1];
imgs = ARGS[2];
dest = ARGS[3];

meta = DataFrame(CSV.File(metafile));

# Rename the 'Column1' column, as this is the row index
rename!(meta, :Column1 => :row_index);
# Remove unusable rows
dropmissing!(meta, :ImageID);

lookup = Dict{String, String}();

for row in eachrow(meta[:,:])
   _ids = row[:ImageID];
   ids = JSON.parse(replace(_ids, "'" => "\""));
   for id in ids
       lookup[id] = JSON.json(
        Dict(
            names(row[Not(:ImageID)]) .=> # Get all column names, except ImageID
            values(row[Not(:ImageID)]) # Get all values, except ImageID
          )
        );
   end
end

counter = 0;
nbfiles=0;
walk = walkdir(imgs);
seen = Dict{String, String}();

for (root, dirs, files) in walk
    for file in files
        println("file=$file");
        occursin(".DS_Store", file) && continue; # short-circuit, if left-hand is true, right-hand is evaluated
        nbfiles+=1;
        !haskey(lookup, file) && continue;
        metaJson = lookup[file];
        destFile = "$dest/$file";
        imgFile = "$root/$file";
        haskey(seen, imgFile) && continue;
        isfile(destFile) && continue;
        gps = []; # has to be an array, as this will be interpolated as individual arguments with the run command.
        row = @from x in meta begin
            @where occursin(file, x.ImageID)
            @select x
            @collect DataFrame
        end
        if !ismissing(row.latitude[1])
            lat = row.latitude[1];
            lon = row.longitude[1];
            alt = row.altitude[1];
            gps = ["-GPSLatitude=$lat", "-GPSLatitudeRef=$lat", "-GPSLongitude=$lon", "-GPSLongitudeRef=$lon", "-GPSAltitude=$alt", "-GPSAltitudeRef=$alt"];
        end
        try
            run(`exiftool $gps -comment=$metaJson -o $destFile $imgFile`);
        catch e
            println(e);
        end
        seen[imgFile] = destFile;
        counter+=1;
    end
end

println("Files seen: $nbfiles")
println("Exif written: $counter")