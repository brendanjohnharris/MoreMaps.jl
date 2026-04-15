module DimensionalDataExt
import DimensionalData: Dimension

function Base.map(f, c::C, ds::Vararg{Dimension}) where {C <: AbstractChart}
    map(f, c, map(collect, ds)...)
end

end
