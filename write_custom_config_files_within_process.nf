Channel
    .from([[['strain_1', 'strain_2'], [file('lmao_this_file_name_is_a_mess_strain1.fasta'), file('strain2_some_totally_random_filename.fasta')]]])
    .set {input_ch}

process software_that_requires_as_custom_config {
    publishDir "custom_config"
    input:
    set val(genome_names), file(genome_fastas) from input_ch
    output:
    file(custom_config) into output_ch
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
