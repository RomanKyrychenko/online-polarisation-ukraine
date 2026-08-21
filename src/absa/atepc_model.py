from pyabsa import AspectTermExtraction as ATEPC
from pyabsa import ModelSaveOption, DeviceTypeOption
from pyabsa import DatasetItem

# Get a configuration template
config = ATEPC.ATEPCConfigManager.get_atepc_config_multilingual()

# Set the model and BERT checkpoint
config.model = ATEPC.ATEPCModelList.FAST_LCF_ATEPC
config.pretrained_bert = "google-bert/bert-base-multilingual-cased"

# Set training hyperparameters
config.num_epoch = 5
config.evaluate_begin = 2
config.max_seq_len = 80
config.log_step = 100
config.dropout = 0.5
config.learning_rate = 1e-5
config.l2reg = 1e-8
config.cache_dataset = False
config.use_amp = True
config.seed = 42


# Choose a dataset
dataset = DatasetItem("politics", ["politics"])

# Start the training
trainer = ATEPC.ATEPCTrainer(
    config=config,
    dataset=dataset,
    checkpoint_save_mode=ModelSaveOption.SAVE_MODEL_STATE_DICT,
    auto_device=DeviceTypeOption.AUTO,
)

"""
# Load a pre-trained aspect extractor
aspect_extractor = ATEPC.AspectExtractor('multilingual')


# Extract aspect terms from multiple sentences
examples = [
    "!  В окружении Путина одни миллиардеры",
    "!  Ось така тепер в Україні \"правда\"!! , ви велика московитська БРЕХНЯ!  зі всіма їхніми проповідниками і провідниками!",
    "!  В чьих интересах работает Путин? | Блог МБХ",
    "!  Ми здобули ще одну перемогу в тому, за що боролися останні 5 років.  Рада США з географічних назв ухвалила рішення виправити офіційну назву столиці України з \"Kiev\" на \"Kyiv\" у міжнародній базі.   Впевнений, це рішення стане п…",
    "!  Угар от \"крымнаша\" развеялся: на Россию надвигается невиданная катастроф..."
]
aspect_extractor.predict(examples)
"""