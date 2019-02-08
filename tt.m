starts = [1,2,2.5,3,7,10,15];
ends  = starts+3;

ignored = false(size(starts));
for i=1:numel(starts)-1
    if ignored(i) 
        continue;
    end
    for j=i+1:numel(starts)
        if starts(j)<=ends(i) % overlaps or inside
            if ends(j)>ends(i) %ovelaps, extend block i
                ends(i)=ends(j);
            end
            ignored(j) = true;
        else
            break
        end
    end    
end
starts = starts(~ignored);
ends   = ends(~ignored);
delta = ends -starts;
