from pyabsa import DatasetItem
from pyabsa import AspectPolarityClassification as APC, available_checkpoints
from pyabsa import ModelSaveOption, DeviceTypeOption
import warnings

# Load a pre-trained multilingual model
# The first time you run this, it will download the model checkpoint
# sentiment_classifier = APC.SentimentClassifier("multilingual")

#print(available_checkpoints(show_ckpts=True))


#classifier = APC.SentimentClassifier(
#    'multilingual',
#    auto_device=True,
#    cal_perplexity=True
#)


config = (
    APC.APCConfigManager.get_apc_config_multilingual()
    #ATEPC.ATEPCConfigManager.get_atepc_config_multilingual()
)  # this config contains 'pretrained_bert', it is based on pretrained models
#config.model = ATEPC.ATEPCModelList.FAST_LCF_ATEPC  # improved version of LCF-ATEPC
config.model = APC.APCModelList.FAST_LCF_BERT
config.pretrained_bert = "google-bert/bert-base-multilingual-cased"

#from pyabsa import make_ABSA_dataset
# refer to the comments in this function for detailed usage
#make_ABSA_dataset(dataset_name_or_path='twitter_texts.txt', checkpoint='multilingual')



#dataset = ATEPC.ATEPCDatasetList.Multilingual

dataset = DatasetItem("politics", ["politics"])
# my_dataset1 and my_dataset2 are the dataset folders. In there folders, the train dataset is necessary



warnings.filterwarnings("ignore")

config.batch_size = 16
config.patience = 2
config.log_step = -1
config.seed = [1]
config.verbose = False  # If verbose == True, PyABSA will output the model strcture and seversal processed data examples
config.notice = (
    "This is an training example for aspect term extraction"  # for memos usage
)

trainer = APC.APCTrainer(
    config=config,
    dataset=dataset,
    #from_checkpoint="english",  # if you want to resume training from our pretrained checkpoints, you can pass the checkpoint name here
    auto_device=DeviceTypeOption.AUTO,  # use cuda if available
    checkpoint_save_mode=ModelSaveOption.SAVE_MODEL_STATE_DICT,  # save state dict only instead of the whole model
    load_aug=False,  # there are some augmentation dataset for integrated datasets, you use them by setting load_aug=True to improve performance
)