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
