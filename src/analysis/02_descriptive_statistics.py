# %%

import os
import json
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

# %%

channel_metadata = pd.read_csv('../telegram_propaganda/data_samples/black_channels.csv')

# %%

# Create an empty list to store the data
data = []

# Specify the directory
directory = '../telegram_propaganda/data_samples/tgstat_scrape/creation_dates'

# Loop through all the files
for filename in os.listdir(directory):
    with open(os.path.join(directory, filename), 'r') as f:
        date = f.read().strip()  # read the file and remove any leading/trailing whitespace
        data.append([filename, date])  # append the filename and date to the data list

# Convert the data list to a pandas DataFrame
creation_dates = pd.DataFrame(data, columns=['username', 'date'])

# Convert the 'date' column to datetime
creation_dates['date'] = pd.to_datetime(creation_dates['date'], format='%d.%m.%Y')

# %%

# Merge the dataframes on 'username'
merged_df = pd.merge(channel_metadata, creation_dates, on='username', suffixes=('_x', ''))

# Drop the 'date_x' column
merged_df = merged_df.drop(columns='date_x')

# Rename the 'date' column
channel_metadata = merged_df.rename(columns={'date': 'date'})

# %%

channel_metadata['date'].value_counts(dropna=False).head(50)

# %%

# Define the directory
directory = '../telegram_propaganda/data_samples/tgstat_scrape/average_post_reach/'

dfs = []

# Iterate over files in the directory
for filename in os.listdir(directory):
    if filename.endswith(".json"):
        with open(directory + filename, 'r') as f:
            data = json.load(f)
            # Extract the data
            temp_df = pd.DataFrame(data['chartData'][0]['data'])
            # Convert the 'x' column to datetime
            temp_df['x'] = pd.to_datetime(temp_df['x'], unit='ms')
            # Rename the columns
            temp_df.columns = ['Date', 'Views', 'Tooltip']
            # Add the channel name (filename without .json) as a new column
            temp_df['Channel'] = filename[:-5]
            # Plot the data for this channel
            dfs.append(temp_df)

average_reach_over_time = pd.concat(dfs)

# %%

# Filter rows between Feb 2022 to Feb 2024
mask = (average_reach_over_time['Date'] >= '2022-02-01') & (average_reach_over_time['Date'] <= '2024-02-28')
filtered_df = average_reach_over_time.loc[mask]

# Calculate mean Views for each Channel
mean_views = filtered_df.groupby('Channel')['Views'].mean()

# Get top 20 channels with highest sum of Views
top_20_channels = mean_views.nlargest(20).index.values

# Rename 'Channel' column to 'username' in mean_views to match with channel_metadata for merging
mean_views = mean_views.reset_index()
mean_views.rename(columns = {'Views': 'average_reach', 'Channel':'username'}, inplace = True)

# Merge mean_views with channel_metadata
channel_metadata = pd.merge(channel_metadata, mean_views, on='username', how='left')

# %%

channel_metadata['average_reach'].value_counts(dropna=False).head(50)

# %%

channel_metadata['average_reach'].describe()

# %%

# Loop through each channel and create a lineplot
for channel in top_20_channels:
    channel_df = average_reach_over_time[average_reach_over_time['Channel'] == channel]
    sns.lineplot(data=channel_df, x='Date', y='Views', color='blue', alpha=0.1)

# Calculate the median subscribers for each date
df_median = average_reach_over_time.groupby('Date')['Views'].mean().reset_index()

# Plot the median line
sns.lineplot(data=df_median, x='Date', y='Views', color='red', label='Average')

blue_patch = mpatches.Patch(color='blue', label='Top-20 channels')
red_patch = mpatches.Patch(color='red', label='Average for 82 channels')
plt.legend(handles=[blue_patch, red_patch])

plt.title('Average Post Reach Over Time')
plt.xticks(rotation='vertical')
plt.show()

# %%

# Define the directory
directory = '../telegram_propaganda/data_samples/tgstat_scrape/subscribers/'

dfs = []

# Iterate over files in the directory
for filename in os.listdir(directory):
    if filename.endswith(".json"):
        with open(directory + filename, 'r') as f:
            data = json.load(f)
            # Extract the data
            temp_df = pd.DataFrame(data['chartData'][0]['data'])
            # Convert the 'x' column to datetime
            temp_df['x'] = pd.to_datetime(temp_df['x'], unit='ms')
            # Rename the columns
            temp_df.columns = ['Date', 'Subscribers', 'Tooltip']
            # Add the channel name (filename without .json) as a new column
            temp_df['Channel'] = filename[:-5]
            # Plot the data for this channel
            dfs.append(temp_df)

subscribers = pd.concat(dfs)

# %%

# Filter rows between Feb 2022 to Feb 2024
mask = (subscribers['Date'] >= '2022-02-01') & (subscribers['Date'] <= '2024-02-28')
filtered_df = subscribers.loc[mask]

# Calculate mean Views for each Channel
top_subscribers = filtered_df.groupby('Channel')['Subscribers'].max()

# Get top 20 channels with highest sum of Views
top_20_channels = top_subscribers.nlargest(20).index.values

# %%

# Loop through each channel and create a lineplot
for channel in top_20_channels:
    channel_df = subscribers[subscribers['Channel'] == channel]
    sns.lineplot(data=channel_df, x='Date', y='Subscribers', color='blue', alpha=0.1)

# Calculate the median subscribers for each date
df_median = subscribers.groupby('Date')['Subscribers'].mean().reset_index()

# Plot the median line
sns.lineplot(data=df_median, x='Date', y='Subscribers', color='red', label='Median')

blue_patch = mpatches.Patch(color='blue', label='Top-20 channels')
red_patch = mpatches.Patch(color='red', label='Average for 82 channels')
plt.legend(handles=[blue_patch, red_patch])

plt.title('Subscribers Over Time')
plt.ylabel('Subscribers (millions)') 
plt.xticks(rotation='vertical')
plt.show()

# %%

# Top 10 channels
pd.set_option('display.float_format', lambda x: '%.0f' % x)
channel_metadata.sort_values('participants_count', ascending=False).head(10)[['username','title','participants_count','date','average_reach']]

# %%

channel_metadata[['participants_count','average_reach']].describe(percentiles=[.25, .5, .75])

# %%

# Calculate the percentiles
date_percentiles = channel_metadata['date'].quantile([.25, .5, .75])

# Calculate the minimum and maximum
date_min = channel_metadata['date'].min()
date_max = channel_metadata['date'].max()

# Print the results
print('Min:', date_min)
print('25th percentile:', date_percentiles[0.25])
print('Median:', date_percentiles[0.5])
print('75th percentile:', date_percentiles[0.75])
print('Max:', date_max)
# %%
