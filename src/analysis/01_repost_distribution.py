# %%

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# %%

black_channels = pd.read_csv('../telegram_propaganda/data_samples/black_channels.csv')
forwards = pd.read_csv('../telegram_propaganda/data_samples/black_post_fwd.csv')
channel_metadata = pd.read_csv('../telegram_propaganda/data_samples/grouped_channels.csv')

forwards['date'] = pd.to_datetime(forwards['date'])
black_channel_names = black_channels.username.values

# %%

# Merging based on 'peer_id'
merged_df = pd.merge(forwards, channel_metadata[['name', 'username', 'group']], left_on='peer_id', right_on='name', how='left')
merged_df.rename(columns={'username': 'channel_name', 'group': 'channel_group'}, inplace=True)

# Dropping the 'name' column
merged_df.drop(columns=['name'], inplace=True)

# Merging based on 'fwd_from_channel_id'
merged_df = pd.merge(merged_df, channel_metadata[['name', 'username', 'group']], left_on='fwd_from_channel_id', right_on='name', how='left', suffixes=('', '_fwd'))
merged_df.rename(columns={'username': 'fwd_from_channel_name', 'group': 'fwd_from_group'}, inplace=True)

# Dropping the 'name' column
merged_df.drop(columns=['name'], inplace=True)

df = merged_df
df['year_month'] = df['date'].dt.strftime('%Y-%m')

# %%

df['channel_name'].value_counts(dropna=False).head(50)

# %%

df['fwd_from_channel_name'].value_counts(dropna=False).head(50)

# %%

df_fwd_from_black = df[df['fwd_from_channel_name'].isin(black_channel_names)]

# %%

df_fwd_from_black['channel_group'].value_counts(dropna=False)

# %%

# Count the frequency of each channel group per month
df_grouped = df_fwd_from_black.groupby(['year_month', 'channel_group']).size().reset_index(name='frequency')
# Convert 'year_month' to string
df_grouped['year_month'] = df_grouped['year_month'].astype(str)

# Create the lineplot
plt.figure(figsize=(15, 8))
sns.lineplot(data=df_grouped, x='year_month', y='frequency', hue='channel_group')
plt.xticks(rotation=90)
plt.title('Frequency of Different Channel Group Values Over Time')
plt.show()

# %%

df_tmp = df_fwd_from_black[df_fwd_from_black['channel_group'] == 2]

# Count the frequency of each channel group per month
df_grouped = df_tmp.groupby(['year_month', 'channel_group']).size().reset_index(name='frequency')
# Convert 'year_month' to string
df_grouped['year_month'] = df_grouped['year_month'].astype(str)

# Create the lineplot
plt.figure(figsize=(15, 8))
sns.lineplot(data=df_grouped, x='year_month', y='frequency', hue='channel_group')
plt.xticks(rotation=90)
plt.title('Frequency of Different Channel Group Values Over Time')
plt.show()

# %%
