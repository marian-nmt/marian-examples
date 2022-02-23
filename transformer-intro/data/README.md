# en-de data

## Training
The training data is a subset of data from the [WMT21] news task.
| Dataset             |     Sentences |
|---------------------|--------------:|
| Europarl v10        |     1,828,521 |
| News Commentary v16 |       398,981 |
| Common Crawl corpus |     2,399,123 |
| **Total**           | **4,626,625** |

## Validation
The validation set uses the [WMT19] news task test set via [sacrebleu].

## Testing
Evaluation of the model uses the [WMT20] news task test set via [sacrebleu].


[wmt19]: https://www.statmt.org/wmt19/translation-task.html
[wmt20]: https://www.statmt.org/wmt20/translation-task.html
[wmt21]: https://www.statmt.org/wmt21/translation-task.html
[sacrebleu]: https://github.com/mjpost/sacrebleu
