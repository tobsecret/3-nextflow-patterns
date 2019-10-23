# 5-nextflow-patterns
This repo contains code snippets and markdown illustrating 5 useful Nextflow patterns.

## 1. Reducing the number of input files during development
Commonly when developing a pipeline, we do not want to run it on all data at once. 
Instead, I like using `take` on my main channel of inputs, only letting a set number of items through the channel.
Because I do not want this to always be the case, I make it conditional on a params variable `params.dev`.
Any variable specified as `params.somevariable` can be set to `somevalue` on the commandline by invoking `nextflow run pipeline.nf --variable somevalue`.
```
params.dev = false
params.number_of_inputs = 2
Channel
    .from(1..300)
    .take( params.dev ? params.number_of_inputs : -1 )
    .println() 
```
*Explanation:*
This example snippet first fills a channel with the numbers from 1 to 300.
Then either `params.number_of_inputs` many of those numbers (here by default 2) or all of them (when `params.dev` is `false` and take receives -1 as input), and prints the numbers that make it through.

In this example `params.dev` is by default `false`, so when developing a pipeline, we simply add the `--dev` flag to set it to true, like so:

`nextflow run conditional_take.nf --dev`

Now our pipeline only lets through the first two numbers:
```
N E X T F L O W  ~  version 19.09.0-edge
Launching `conditional_take.nf` [scruffy_shannon] - revision: 1e3507df3d
1
2
```
If we were to run the pipeline without the `--dev` flag, it prints all the numbers from 1 to 300:
```
N E X T F L O W  ~  version 19.09.0-edge
Launching `conditional_take.nf` [scruffy_shannon] - revision: 1e3507df3d
1
2
3
[4-298 omitted here]
299
300
```

