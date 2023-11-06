
### Per https://medium.com/@ahmettsdmr1312/fine-tuning-distilbert-for-emotion-classification-84a4e038e90e#:~:text=Fine%2Dtuning%20models%20like%20DistilBERT,text%20classification%20in%20various%20applications.
from datasets import Dataset
from datasets import load_dataset
import pandas as pd
import pyreadr
import torch
from transformers import set_seed
### from transformers import DistilBertForSequenceClassification
set_seed(617)

file = "data/gold_standard_sentences_duckled_and_parsed.csv"

torch.cuda.empty_cache()

try:
    df = pd.read_csv(file)
except OSError as err:
    print("OS error:", err)
except Exception as err:
    print(f"Unexpected {err=}, {type(err)=}")
    raise

### df is a pandas data frame
### prune the dataset

df = pd.DataFrame(data = df)
df = df[['newtext', 'Revision']]
mapping = {'Past': 0, 'Present': 1, 'Future': 2}
df['labels'] = df['Revision'].map(mapping)

temporal = Dataset.from_pandas(df)

### Tokenization
from transformers import AutoTokenizer

model_ckpt = "distilbert-base-cased"

tokenizer = AutoTokenizer.from_pretrained(model_ckpt)

def tokenize(batch):
    return tokenizer(batch["newtext"], padding=True, truncation=True)

temporal_encoded = temporal.map(tokenize, batched=True)

from transformers import AutoModelForSequenceClassification

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
num_labels = 3
id2label = {
    "0": "Past",
    "1": "Present",
    "2": "Future",
}
label2id = {
    "Past": 0,
    "Present": 1,
    "Future": 2,
}

model = AutoModelForSequenceClassification.from_pretrained(model_ckpt, num_labels=num_labels, id2label=id2label, label2id=label2id).to(device)

from transformers import Trainer, TrainingArguments

temporal_encoded = temporal_encoded.train_test_split(test_size=0.2)

batch_size = 32
logging_steps = len(temporal_encoded["train"]) // batch_size
model_name = f"{model_ckpt}-finetuned-temporal"


training_args = TrainingArguments(
    output_dir=model_name,
    num_train_epochs=2,
    learning_rate=2e-5,
    per_device_train_batch_size=batch_size,
    per_device_eval_batch_size=batch_size,
    weight_decay=0.01,
    evaluation_strategy="epoch",
    disable_tqdm=False,
    logging_steps=logging_steps,
    push_to_hub=False,
    log_level="error"
)

### Here there's a bit of code not specified
import numpy as np
import evaluate
accuracy = evaluate.load("accuracy")

def compute_metrics(eval_pred):
    predictions, labels = eval_pred
    predictions = np.argmax(predictions, axis=1)
    return accuracy.compute(predictions=predictions, references=labels)

trainer = Trainer(
    model=model,
    args=training_args,
    compute_metrics=compute_metrics,
    train_dataset=temporal_encoded["train"],
    eval_dataset=temporal_encoded["test"],
    tokenizer=tokenizer
)

trainer.train()

### How quickly can we make predictions?
predictions = trainer.predict(temporal_encoded["test"])
print(predictions.predictions.shape, predictions.label_ids.shape)

outdat = pd.DataFrame(predictions.predictions)
outdat = outdat.assign(Label = temporal_encoded["test"]["labels"])

outdat.to_csv("working/distilbert_predictions.csv", index = False)
preds = np.argmax(predictions.predictions, axis=-1)
pcp_003 = np.mean(preds == temporal_encoded["test"]["labels"])

import time
start = time.time()
trainer.predict(temporal_encoded["test"])
end = time.time()
print(end - start)

### How do we save these models?
trainer.save_model("working/model_objects")
