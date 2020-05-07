postConts = ["post/filtered.seqTab.RDS","reporting/post_finalNumbers_perSample.tsv"]
if config['hand_off']['phyloseq']:
    postConts.append("post/filtered.seqTab.phyloseq.RDS")
if config['postprocessing']['treeing']['do']:
    postConts.append("post/tree.newick")
if config['postprocessing']['rarefaction_curve']:
    postConts.append("stats/rarefaction_curves.pdf")
if config['postprocessing']['funguild']['do']:
    postConts.append("post/filtered.seqTab.guilds.tsv")

localrules: post_control_Filter

rule post_control_Filter:
    input:
        postConts
    output:
        "postprocessing.done"
    shell:
        """
        touch {output}
        """

filtTabs = ["sequenceTables/all.seqs.fasta"]
if config['do_taxonomy'] and (config['taxonomy']['decipher']['do'] or config['taxonomy']['mothur']['do']):
    filtTabs.append("sequenceTables/all.seqTab.tax.RDS")
else:
    filtTabs.append("sequenceTables/all.seqTab.RDS")
rule filtering_table:
    input: 
       filtTabs
    output:
       "post/filtered.seqTab.RDS",
       "post/filtered.seqTab.tsv",   
       "post/filtered.seqs.fasta"  
    threads: 1
    params:
        mem="8G",
        runtime="2:00:00"
    log: "logs/post_filtering_table.log"
    conda: ENVDIR + "dada_env.yml"
    script:
        SCRIPTSDIR+"post_filtering.R"

rule table_filter_numbers:
    input:
        "reporting/finalNumbers_perSample.tsv",
        "post/filtered.seqTab.RDS"
    output:
        "reporting/post_finalNumbers_perSample.tsv"
    threads: 1
    params:
        currentStep = "post",
        mem="8G",
        runtime="12:00:00"
    conda: ENVDIR + "dada_env.yml"
    log: "logs/countPostfilteredReads.log"
    script:
        SCRIPTSDIR+"report_readNumbers.R"


rule rarefaction_curve_Filter:
    input:
        "post/filtered.seqTab.RDS",
        "reporting/post_finalNumbers_perSample.tsv"
    output:
        "stats/rarefaction_curves.pdf"
    threads: 1
    params:
        mem="8G",
        runtime="12:00:00"
    conda: ENVDIR + "dada_env.yml"
    log: "logs/rarefaction_curve.log"
    script:
        SCRIPTSDIR+"rarefaction_curve.R"


rule guilds_Filter:
    input:
        "post/filtered.seqTab.tsv"
    output:
        "post/filtered.seqTab.guilds.tsv"
    threads: 1
    params:
        mem="8G",
        runtime="12:00:00",
        src_path=SCRIPTSDIR
    log: "logs/funguild.log"
    conda: ENVDIR + "dada_env.yml"
    message: "Running funguild on {input}."
    shell:
        """
        {params.src_path}/Guilds_v1.1.local.2.py -otu {input} -output {output} -path_to_db {config[postprocessing][funguild][funguild_db]} -taxonomy_name taxonomy.{config[postprocessing][funguild][classifier]} &> {log}
        """

if config['hand_off']['phyloseq']:
    physInputs = ["post/filtered.seqTab.RDS","reporting/post_finalNumbers_perSample.tsv"]
    physOutputs = "post/filtered.seqTab.phyloseq.RDS"
    if config['postprocessing']['treeing']['do']:
        physInputs.append("post/tree.newick")
    rule phyloseq_handoff_postFilter:
        input:
            physInputs
        output:
            "post/filtered.seqTab.phyloseq.RDS"
        threads: 1
        params:
            currentStep = "post",
            mem="8G",
            runtime="12:00:00"
        conda: ENVDIR + "dada_env.yml"
        log: "logs/phyloseq_hand-off.log"
        script:
            SCRIPTSDIR+"phyloseq_handoff.R"

if config['postprocessing']['treeing']['fasttreeMP'] != "":
    rule treeing_Filter_fasttreeMP:
        input:
            "post/filtered.seqs.fasta"
        output:
            "post/filtered.seqs.multi.fasta",
            "post/tree.newick"
        threads: 10
        params:
            mem="8G",
            runtime="12:00:00"
        conda: ENVDIR + "dada_env.yml"
        log: "logs/treeing.log"
        shell:
            """
            clustalo -i {input} -o {output[0]} --outfmt=fasta --threads={threads} --force
            {config[postprocessing][treeing][fasttreeMP]} -nt -gamma -no2nd -fastest -spr 4 \
             -log {log} -quiet {output[0]} > {output[1]}
            """
else:
    rule treeing_Filter:
        input:
            "post/filtered.seqs.fasta"
        output:
            "post/filtered.seqs.multi.fasta",
            "post/tree.newick"
        threads: 1
        params:
            mem="8G",
            runtime="12:00:00"
        conda: ENVDIR + "dada_env.yml"
        log: "logs/treeing.log"
        shell:
            """
            clustalo -i {input} -o {output[0]} --outfmt=fasta --threads={threads} --force
            fasttree -nt -gamma -no2nd -fastest -spr 4 \
             -log {log} -quiet {output[0]} > {output[1]}
            """


