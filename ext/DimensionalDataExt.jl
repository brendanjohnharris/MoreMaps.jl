module DimensionalDataExt
import DimensionalData: Dimension
import MoreMaps: AbstractChart

function Base.map(f, c::C, ds::Vararg{Dimension}) where {C <: AbstractChart}
    return map(f, c, map(collect, ds)...)
end

end
