# 5-nextflow-patterns
This repo contains code snippets and markdown illustrating 5 useful Nextflow patterns.

## 1. Reducing the number of input files during development
Commonly when developing a pipeline, we do not want to run it on all data at once. 
Instead, I like using the `take` operator on my main channel of inputs, only letting a set number of items through the channel.
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
## 2. Collecting output files of a process with publishDir
Nextflow frees us from thinking about where files produced by a process end up and making sure they are available for the next process that uses them. 
However, often we want to see files output by a process without having to dig into the work directory. 
For this we use the `publishDir` directive in our process to tell Nextflow in which directory we want to publish our files that are tracked in the `output:` channel(s) of the process. 

**publishDir** is the NUMBER ONE THING new users ask for on the Nextflow [gitter channel](https://gitter.im/nextflow-io/nextflow) because we are so used to having to track where files are manually.

The `publishDir` directive takes a directory relative to where we are running the pipeline from. 
We can also give it a glob `pattern` to specify files with which extensions should be published. 
Although it's not explicitly mentioned in the documentation, we can specify `publishDir` multiple times, which can be useful if a process produces multiple types of files and we want to publish several different groupings of the same files.
Also useful, `publishDir` allows us to provide a closure to specify the path/ filename a file should be `saveAs` (relative to the publishDir), given the name of the file.

This last one is a bit tricky because the closure does not get passed a file object but just a string.
Hence, in order to use file methods like `getSimpleName`, we first have to turn turn the passed string into a file `file(it)`.

I have coded up an example below, where we pass a fruit and a baked good to `someprocess` and publish the resulting `fruit_file` and `pastry_file` in different directories:
```
Channel
    .from(['apples', 'tarte'], ['peach', 'pie'])
    .set{input_ch}

process someprocess {
    publishDir "fruits", pattern: '*.fruit', saveAs: { "${file(it).getSimpleName()}.${file(it).getExtension()}"}
    publishDir "pastries", pattern: '*.pastry'
    input:
    set val(fruit), val(pastry) from input_ch
    output:
    set file(fruit_file), file(pastry_file) into output_ch
    script:
    fruit_file = "${fruit}.pastry.fruit"
    pastry_file = "${pastry}.fruit.pastry"
    """
    touch $fruit_file
    touch $pastry_file
    """
}
```
We want to publish the fruit\_files in the directory fruits and want to only keep the last file extension and the file name (i.e. remove the .pastry from the file).
The pastry\_files we will publish in the pastries directory.

Let's run it:
`nextflow run do_you_have_a_minute_to_talk_about_publishdir.nf`

```
N E X T F L O W  ~  version 19.09.0-edge
Launching `do_you_have_a_minute_to_talk_about_publishdir.nf` [mad_mestorf] - revision: d436b24a1c
executor >  local (2)
[92/97d75e] process > someprocess (2) [100%] 2 of 2 ✔
```

Let's see where our files ended up:
```
$ ls fruits
apples.fruit
peach.fruit
$ ls pastries
pie.fruit.pastry
tarte.fruit.pastry
```
Perfect, this is what we specified the two separate `publishDir` directives for - see the fruits only have one extension whereas the pastries retained all of theirs.
Note that you could also publish the same file multiple times, which can be useful in some instances.

Finally, by default publishDir makes a symbolic link but you can also have the files copied, hard-linked, or even moved. 
The latter is not recommended because it breaks reruns.


