params.dev = false
params.number_of_inputs = 5
Channel
    .from(1..300)
    .take( params.dev ? params.number_of_inputs : -1 )
    .println() 
