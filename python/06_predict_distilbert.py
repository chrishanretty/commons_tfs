from transformers import pipeline, AutoModel, AutoTokenizer
from transformers import TextClassificationPipeline
from transformers import AutoModelForSequenceClassification
from transformers.pipelines.pt_utils import KeyDataset
import  pandas as pd
from datasets import Dataset, load_dataset
import os
import os.path
import pyreadr
from random import shuffle

# Replace with your custom model of choice
model = AutoModelForSequenceClassification.from_pretrained('chanret/tfs_distilbert')
tokenizer = AutoTokenizer.from_pretrained('chanret/tfs_distilbert')

text = "In the future, everyone will be famous for fifteen minutes. "

classify = TextClassificationPipeline(model=model, tokenizer=tokenizer,
                                top_k = None)
classify(text)

text = 'A long time ago, in a galaxy far away, two Jedi battled. '
classify(text)

### Now we need to do it for .rds one at a time

def list_of_lists2pd(l):
    inner_list = l
    labels = [item['label'] for item in inner_list]
    scores = [item['score'] for item in inner_list]
    # Create a DataFrame from the extracted data
    df = pd.DataFrame([scores], columns=labels)
    return(df)


def parse_file(file):
    df = pyreadr.read_r(file)[None]
    dataset = Dataset.from_pandas(df)
    outfile = file.replace("ducked", "distilled")
    if os.path.isfile(outfile):
        return True
    batch_size = 12
    res = [list_of_lists2pd(out) for out in classify(KeyDataset(dataset, "newtext"), batch_size = batch_size, truncation = True)]
    res = pd.concat(res)
    df = df.reset_index(drop = True)
    res = res.reset_index(drop = True)
    out = pd.concat([df, res], axis = 1)
    out = out.reset_index(drop = True)
    outfile = file.replace("ducked", "distilled")
    outfile = outfile.replace(".rds", ".parquet")
    out.to_parquet(outfile)


def list_full_paths(directory):
    return [os.path.join(directory, file) for file in os.listdir(directory)]

foo = list_full_paths("working/ducked")
shuffle(foo)

for f in foo:
    parse_file(f)



