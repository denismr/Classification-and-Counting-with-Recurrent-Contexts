import argparse
import numpy as np
import pandas as pd
import random

from sklearn.ensemble import RandomForestClassifier

from sklearn.model_selection import KFold

parser = argparse.ArgumentParser()

parser.add_argument('-exp', '--experiment', type=str, default='')
parser.add_argument('-cl', '--classifier', type=str, default='RF')

args = parser.parse_args()

CCons = {
  'RF': (RandomForestClassifier, {'n_estimators': 500})
}

def CreateClassifier():
  constructor, kw = CCons[args.classifier]
  return constructor(**kw)

experiments = {
  'AedesQuinx': {
    'dataset': 'AedesQuinx',
    'ctx_feature': 'temp_range',
    'ctx_feature_values': [1, 2, 3, 4, 5, 6],
    'target': 'species',
    'features': ["wbf","eh_1","eh_2","eh_3","eh_4","eh_5","eh_6","eh_7","eh_8","eh_9","eh_10","eh_11","eh_12","eh_13","eh_14","eh_15","eh_16","eh_17","eh_18","eh_19","eh_20","eh_21","eh_22","eh_23","eh_24","eh_25"],
    'positive_class': 'AA',
  },
  'AedesSex': {
    'dataset': 'AedesSex',
    'ctx_feature': 'temp_range',
    'ctx_feature_values': [1, 2, 3, 4, 5, 6],
    'target': 'sex',
    'features': ["wbf","eh_1","eh_2","eh_3","eh_4","eh_5","eh_6","eh_7","eh_8","eh_9","eh_10","eh_11","eh_12","eh_13","eh_14","eh_15","eh_16","eh_17","eh_18","eh_19","eh_20","eh_21","eh_22","eh_23","eh_24","eh_25"],
    'positive_class': 'F',
  },
  'ArabicSex': {
    'dataset': 'ArabicDigit',
    'ctx_feature': 'digit',
    'ctx_feature_values': [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    'target': 'sex',
    'features': lambda x:  x != 'sex' and x != 'digit',
    'positive_class': 'male',
  },
  'QG': {
    'dataset': 'qg',
    'ctx_feature': 'author',
    'ctx_feature_values': [
      'Andre', 'Antonio', 'Denis', 'Diego', 'Felipe',
      'Gustavo', 'Minatel', 'Rita', 'Roberta', 'Sanches',
    ],
    'target': 'letter',
    'features': lambda x:  x != 'author' and x != 'letter',
    'positive_class': 'q',
  },
  'CMC': {
    'dataset': 'cmc',
    'ctx_feature': 'wifes_age',
    'ctx_feature_values': [1, 2],
    'target': 'contraceptive',
    'features': lambda x:  x != 'contraceptive' and x != 'wifes_age',
    'positive_class': 1,
  },
  'WineQuality': {
    'dataset': 'winequality',
    'ctx_feature': 'type',
    'ctx_feature_values': [1, 2],
    'target': 'quality',
    'features': lambda x:  x != 'quality' and x != 'type',
    'positive_class': 'higher',
  },
}

if not args.experiment in experiments:
  print('Invalid experiment')
  exit(0)

exp = experiments[args.experiment]
dataset = exp['dataset']
ctx_feature = exp['ctx_feature']
ctx_feature_values = exp['ctx_feature_values']
target = exp['target']
positive_class = exp['positive_class']

number_of_contexts = 0
stream_size = 0

data = pd.read_csv('data/%s.csv' % dataset, index_col=False)

features = exp['features'] if isinstance(exp['features'], list) \
  else list(filter(exp['features'], data.columns))

print(features)
exit(0)

topfeatures = None

if args.experiment == 'QG':
  f = list(data[ctx_feature])
  m = list(set(f))
  m = dict(zip(m, range(len(m))))
  f = [m[x] for x in f]
  data['topfeature'] = f
  topfeatures = features + ['topfeature']
else:
  topfeatures = features + [ctx_feature]

# print(len(data))
data_indices = list(range(len(data)))
random.shuffle(data_indices)

# train_data = data
train_data = data.iloc[data_indices[:len(data_indices)//2]]
test_data = data.iloc[data_indices[len(data_indices)//2:]]

df = pd.DataFrame(0, index=np.arange(len(data)), columns=['actual_y', 'actual_context', 'baseline_y', 'baseline_p', 'original_index'])

for a in ctx_feature_values:
    key_y = '%s_y' % a
    key_p = '%s_p' % a
    df[key_y] = np.zeros(len(df))
    df[key_p] = np.zeros(len(df))

df['actual_y'] = data[target]
df['actual_context'] = data[ctx_feature]
df['original_index'] = list(range(len(data)))

def UpdateValDF(train_data, test_data, train_index, validation_index, valcol_y, valcol_p, istop = False):
  _features = topfeatures if istop else features
  classifier = CreateClassifier()
  print('    Training')
  classifier.fit(train_data[_features].loc[train_index], train_data[target].loc[train_index])
  print('    Estimating classes')
  df.loc[validation_index, valcol_y] = classifier.predict(test_data[_features].loc[validation_index])
  print('    Estimating probabilities')
  result = classifier.predict_proba(test_data[_features].loc[validation_index])
  positive_index = np.where(classifier.classes_ == positive_class)[0][0]
  df.loc[validation_index, valcol_p] = list(map(lambda x: x[positive_index], result))


kf = KFold(n_splits = 10, shuffle=True)
current_fold = 0
for _train_index, _validation_index in kf.split(train_data):
  train_index = train_data.iloc[_train_index].index
  validation_index = train_data.iloc[_validation_index].index

  current_fold += 1
  print('Current fold: %d' % current_fold)
  print('  Baseline')
  UpdateValDF(train_data, train_data, train_index, validation_index, 'baseline_y', 'baseline_p')
  print('  Topline')
  UpdateValDF(train_data, train_data, train_index, validation_index, 'topline_y', 'topline_p', True)
  for a in ctx_feature_values:
    print('  CTX %s' % a)
    key_y = '%s_y' % a
    key_p = '%s_p' % a
    ctx_ind = train_data.index[train_data.loc[:, ctx_feature] == a]
    inter = ctx_ind.intersection(train_index)
    UpdateValDF(train_data, train_data, inter, validation_index, key_y, key_p)

print('Test data')
print('  Baseline')
train_index = train_data.index
test_index = test_data.index
UpdateValDF(train_data, test_data, train_index, test_index, 'baseline_y', 'baseline_p')
print('  Topline')
UpdateValDF(train_data, test_data, train_index, test_index, 'topline_y', 'topline_p', True)
for a in ctx_feature_values:
  print('  CTX %s' % a)
  key_y = '%s_y' % a
  key_p = '%s_p' % a
  ctx_ind = train_data.index[train_data.loc[:, ctx_feature] == a]
  UpdateValDF(train_data, test_data, ctx_ind, test_index, key_y, key_p)

val_df = df.iloc[data_indices[:len(data_indices)//2]]
test_df = df.iloc[data_indices[len(data_indices)//2:]]

val_df.to_csv('procdata/%s_val.csv' % args.experiment, index=False)
test_df.to_csv('procdata/%s_test.csv' % args.experiment, index=False)