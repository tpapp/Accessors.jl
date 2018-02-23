using Setfield
import Setfield: @focus
using Base.Test
using StaticArrays

struct T
    a
    b
end

struct TT{A,B}
    a::A
    b::B
end

@testset "@set" begin

    t = T(1, T(2, T(T(4,4),3)))
    s = @set t.b.b.a.a = 5
    @test t === T(1, T(2, T(T(4,4),3)))
    @test s === T(1, T(2, T(T(5, 4), 3)))
    @test_throws ArgumentError @set t.b.b.a.a.a = 3

    t = T(1,2)
    @test T(1, T(1,2)) === @set t.b = T(1,2)
    @test_throws ArgumentError @set t.c = 3

    t = T(T(2,2), 1)
    s = @set t.a.a = 3
    @test s === T(T(3, 2), 1)

    t = T(1, T(2, T(T(4,4),3)))
    s = @set t.b.b = 4
    @test s === T(1, T(2, 4))

    t = T(1,2)
    s = @set t.a += 1
    @test s === T(2,2)

    t = T(1,2)
    s = @set t.b -= 2
    @test s === T(1,0)

    t = T(10, 20)
    s = @set t.a *= 10
    @test s === T(100, 20)

    t = T(2,1)
    s = @set t.a /= 2
    @test s === T(1.0,1)

    t = T((1,2),(3,4))
    s = @set t.a[1] = 10
    @test s === T((10,2),(3,4))
    @set t.a[3] = 10

    v = randn(3)
    s = @set v[:] = 1
    @test s == [1,1,1.]
    s = @set s[2:3] = 4
    @test s == [1,4,4]

    t = @set T(1,2).a = 2
    @test t === T(2,2)
end

struct Person
    name::Symbol
    birthyear::Int
end

struct SpaceShip
    captain::Person
    velocity::SVector{3, Float64}
    position::SVector{3, Float64}
end

@testset "SpaceShip" begin
    s = SpaceShip(
                  Person("julia", 2009),
                  [0,0,0],
                  [0,0,0]
                 )
    s = @set s.captain.name = "JULIA"
    s = @set s.velocity[1] += 10
    s = @set s.position[2]  = 20
    @test s === SpaceShip(Person("JULIA", 2009), [10.0, 0.0, 0.0], [0.0, 20.0, 0.0])
end

@testset "show it like you build it " begin
    obj = T(1,2)
    i = 3
    for item in [
            @lens _.a
            @lens _[1]
            @lens _.a.b[2]
            @lens _
            @focus obj[1]
            @focus obj.a
            @focus obj[1].a[i].b
            @focus obj
        ]
        buf = IOBuffer()
        show(buf, item)
        item2 = eval(Meta.parse(String(take!(buf))))
        @test item === item2
    end
end

function test_getset_laws(lens, obj, val1, val2)

    # set ∘ get
    val = get(lens, obj)
    @test set(lens, obj, val) == obj

    # get ∘ set
    obj1 = set(lens, obj, val1)
    @test get(lens, obj1) == val1

    # set idempotent
    obj12 = set(lens, obj1, val2)
    obj2 = set(lens, obj, val2)
    @test obj12 == obj2
end

function test_modify_law(f, lens, obj)
    obj_modify = modify(f, lens, obj)
    old_val = get(lens, obj)
    val = f(old_val)
    obj_setfget = set(lens, obj, val)
    @test obj_modify == obj_setfget
end

@testset "lens laws" begin
    obj = T(2, T(T(3,(4,4)), 2))
    for lens ∈ [
            @lens _.a
            @lens _.b
            @lens _.b.a
            @lens _.b.a.b[2]
            @lens _
        ]
        val1, val2 = randn(2)
        f(x) = (x,x)
        test_getset_laws(lens, obj, val1, val2)
        test_modify_law(f, lens, obj)
    end
end

@testset "type stability" begin
    obj = TT(2, TT(TT(3,(4,4)), 2))
    for lens ∈ [
            @lens _.a
            @lens _.b
            @lens _.b.a
            @lens _.b.a.b[2]
            @lens _
        ]
        @inferred get(lens, obj)
    end

end

@testset "IndexLens" begin
    l = @lens _[]
    x = randn()
    obj = Ref(x)
    @test get(l, obj) == x

    l = @lens _[][]
    inner = Ref(x)
    obj = Base.RefValue{typeof(inner)}(inner)
    @test get(l, obj) == x

    obj = (1,2,3)
    l = @lens _[1]
    @test get(l, obj) == 1
    @test set(l, obj, 6) == (6,2,3)

    obj = @SMatrix [1 2; 3 4]
    l = @lens _[2,1]
    @test get(l, obj) == 3
    @test_broken set(l, obj, 5) == @SMatrix [1 2; 5 4]
    @test_broken setindex(obj, 5, 2, 1) == @SMatrix [1 2; 5 4]

    l = @lens _[1:3]
    @test get(l, [4,5,6,7]) == [4,5,6]
end

mutable struct M
    a
    b
end

@testset "Mutability" begin
    v_init = [1,2,3]
    v = v_init
    @set v[1] = 2
    @test v_init[1] == 2
    @test v === v_init
    m_init = M(1,2)
    m = m_init
    @set m.a = 10
    @test m_init.a == 10
    @test m === m_init

    # composition only mutates the innermost
    m_inner_init = M(1,2)
    m_init = M(m_inner_init, 2)
    m = m_init
    @set m.a.a = 2
    @test m.a.a == 2
    @test m === m_init
    @test m.a === m_inner_init
end
