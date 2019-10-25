# 3-nextflow-patterns
This repo contains code snippets and markdown illustrating 3 useful Nextflow patterns.

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
Launching 'conditional_take.nf' [scruffy_shannon] - revision: 1e3507df3d
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
Launching 'do_you_have_a_minute_to_talk_about_publishdir.nf' [mad_mestorf] - revision: d436b24a1c
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

## 3. Making a custom config file within a process
Some software requires a custom config file. 
Now while of course we could require our end-user to supply a config file to our pipeline, if possible, we'd like to automate that - it usually just adds unnecessary complexity to workflows that we want to hide from the user.

Let's break the code for this example up into bits.
First the input:
```
Channel
    .from([[
           ['strain_1', 'strain_2'],
           [file('lmao_this_file_name_is_a_mess_strain1.fasta'), 
            file('strain2_some_totally_random_filename.fasta')]
           ]])
    .set {input_ch}
```
A common reason why tools require you to specify some config file is them having multiple input files. 
Here our `input_ch` consist of some genome names (strain\_1 and strain\_2) and their associated fasta files which are required for our example config file format.

Having a separate name for a genome could be necessary because filenames can include forbidden characters for some output file format.
An example would be parentheses in genome names being forbidden in Newick files because they have syntactic meaning.


```
process software_that_requires_as_custom_config {
    publishDir "custom_config"
    input:
    set val(genome_names), file(genome_fastas) from input_ch
    output:
    file(custom_config) into output_ch
```
The first portion of this process definition is just the usual - input channels and output channels and for convenience of the example, a publishDir.

In the script part we first transpose the `genome_names` and `genome_fastas` to get a list of lists in which each name is paired up with its corresponding fasta file.

*Building a multi-line Groovy string --> one-line bash string*

Here is what we want our final config file to look like:
```
$ cat custom_config/custom.config
#list of all our genome_names and genome_fastas:
strain_1 = lmao_this_file_name_is_a_mess_strain1.fasta
strain_2 = strain2_some_totally_random_filename.fasta
```
We build the text of our config file into a variable `config_file`.
The intent here is to make a one-line string that we can printf into our config file.

We indent it to make it more readable and strip those indents again with `stripIndents`. 
Note that this will only work if the indents are the same for every line
\- it's crucial that the first line of this multiline string only has the """ and nothing else.
Otherwise `stripIndents` would count this multiline string as not indented.

An additional gotcha is that this multiline Groovy string should eventually turn into one line in bash. 
As a result, to get a `\n` (newline character for printf) in our bash script, we have to write `\\n` in our Groovy script.


Then we can use `collect` to add a custom string for each name \& fasta pairing to our config file.

This produces a list and we don't want the `[]` to end up in our string, so we additionally use `join` to concatenate all the list items into a string.

Finally the whole string needs to be split by newline (this is the Groovy newlines, not our `\\n`) and joined again.

The actual bash portion of this script just `printf`s the contents of our one-line string into our config file.
```
    script:
    custom_config = 'custom.config'
    name_fasta_pairing = [genome_names, genome_fastas.collect()].transpose() // these are now organized like this: [[name1, fasta1], [name2, fasta2]]
    config_file = """
                  #list of all our genome_names and genome_fastas:\\n
                  ${name_fasta_pairing.collect{"${it[0]} = ${it[1]}\\n"}.join()}
    """.stripIndent().split('\n').join('')
    """
    printf '$config_file' >> $custom_config
    """
}
```
Now you may wonder why we needed to go through all the nonsense of escaping bash syntax in our Groovy string - why not make a Groovy string and write directly to a file using Groovy?

The problem here lies with where this Groovy code gets executed. 
The following would create a the config file in the directory from where we run the workflow, rather than inside the work directory:
```
    config_file = """
                  #list of all our genome_names and genome_fastas:
                  ${name_fasta_pairing.collect{"${it[0]} = ${it[1]}\n"}.join()}
    """.stripIndent()
    file(custom_config) << config_file
```
This leads to problems because the file would be overwritten every run, so for now our clunky solution has to do.

Let's run it:
`nextflow run write_custom_config_files_within_process.nf`

```
N E X T F L O W  ~  version 19.09.0-edge
Launching 'write_custom_config_files_within_process.nf' [special_cuvier] - revision: 08a6a5850d
executor >  local (1)
[1b/a693d8] process > software_that_requi... [100%] 1 of 1 ✔
```
And it looks just how we wanted it:
```
$ cat custom_config/custom.config
#list of all our genome_names and genome_fastas:
strain_1 = lmao_this_file_name_is_a_mess_strain1.fasta
strain_2 = strain2_some_totally_random_filename.fasta
```

I  hope this article was informative and you learned at least one new thing.
