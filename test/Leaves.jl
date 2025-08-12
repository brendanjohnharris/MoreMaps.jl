x = [[randn(n) for n in rand(1:5, NN)] for NN in 1:5]

f = x -> x^2

C = Cartographer.Chart()
map(C, f, x)
