from transformers import AutoTokenizer, AutoModelForTokenClassification
from transformers.pipelines import pipeline
import json
from typing import List, Dict, cast

# 1. טען את המודל להגדרת חלק הדיבר
tokenizer = AutoTokenizer.from_pretrained("ShaltielShmidman/DictaBERT-morph")
model = AutoModelForTokenClassification.from_pretrained("ShaltielShmidman/DictaBERT-morph")

nlp = pipeline("token-classification", model=model, tokenizer=tokenizer, aggregation_strategy="simple")

# 2. טען קובץ מילים בסיסי (למשל את מילת 50k הנפוצות)
with open("he_full.txt", encoding="utf-8") as f:
    words: List[str] = [w.strip() for w in f if w.strip()]

filtered: List[str] = []
for word in words:
    # We cast here because the pipeline can return different types, but for our use case
    # we expect a list of dictionaries.
    preds = cast(List[Dict[str, str]], nlp(word))
    if len(preds) == 1:
        pred = preds[0]
        tag: str = pred["entity_group"]  # NN, VB, PRP וכו'
        if tag in {"NN", "VB", "JJ"}:
            filtered.append(word)

# 3. שמור את המילים המסוננות לקובץ JSON
with open("bonus_words.json", "w", encoding="utf-8") as f:
    json.dump({"words": filtered}, f, ensure_ascii=False, indent=2)

print(f"Filtered {len(filtered)} words out of {len(words)}")
