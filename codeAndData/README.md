# Description of the scripts

 - **CreateScoreDatasets.py:** splits the datasets into half and creates the validation and test scores, with Random Forest, as described in the paper. Run with `python CreateScoreDatasets.py -exp <EXPERIMENT NAME>`. Look up at the beginning of the file for a list of possible experiments. This file requires [sklearn](http://scikit-learn.org/);
 - **CheckUnimodal.lua:** reports the frequency of cases where linear seach on _p_ would find no-unimodal situations inside HDy. Runs with `luajit CheckUnimodal --exp <EXPERIMENT NAME>`. Look up at the beginning of the file for a list of possible experiments.
 - **CreateMINASStream.lua:** creates a stream for comparing against MINAS, and also reports our proposals performance. The streaming is a list of indices (which rows of the original dataset file). Use it the same way as with CheckUnimodal.
 - **Experiments.lua:** runs the experiments described in the paper. Use it the same way as with CheckUnimodal.
