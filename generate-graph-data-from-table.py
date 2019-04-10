#!/usr/bin/env python
# coding: utf-8

# In[15]:


import pandas as pd
import matplotlib
import matplotlib.pyplot as plt
import sys
import os.path


# In[16]:


grid_defs = [[13, 5417], [14, 10928], [15, 42947], [16, 223953], [17, 1500457]]
grid = pd.DataFrame(grid_defs, columns=['level', 'grids'])
grid.set_index('level')

def num_grids(table, level):
    num_grids = table[ table['level']==level].grids.iloc[0]
    return num_grids


# In[20]:


inputfile = sys.argv[1] if len(sys.argv)>1 else ''
if not os.path.isfile(inputfile):
    inputfile='cori-timings.txt'
print('reading table from', inputfile)

df = pd.read_csv(inputfile, comment='#', delim_whitespace=True, names=['network', 'nodes', 'level', 'time'])
df.sort_values(by=['level', 'nodes'], ascending=True, inplace=True)
reference_speed = df[(df['network']=='mpi') & (df['nodes']==1) & (df['level']==14)].time.iloc[0]
reference_speed = reference_speed/15.0
reference_grids = num_grids(grid, 14)
print("reference speed is:", reference_speed)
print("reference grid is:", reference_grids)


# In[21]:


df['grids'] = df.apply(lambda row: 15*num_grids(grid, row.level), axis=1)
df['speedup'] = (df['grids']/reference_grids)*reference_speed/df['time']
df['grids/s'] = df['grids']/df['time']
print(df)


# In[22]:


fig, (ax1, ax2) = plt.subplots(nrows = 2, ncols = 1, figsize=(8,12), dpi= 80, facecolor='w', edgecolor='k')
markers = {}
markers['14'] = 'x'
markers['15'] = '.'
markers['16'] = '+'
markers['17'] = 'o'

for net, grp in df.groupby(['network']):
    for lev, grp2 in grp.groupby(['level']):
        r = 0.0 if net=='mpi' else 1.0
        g = 0.2
        b = (18-lev)/4
        colour = 'black' if net=='mpi' else 'blue'
        ax1.plot(grp2['nodes'],
                 grp2['speedup'],
                 color=(r,g,b),
                 marker=markers[str(lev)],
                 label = net + " Level {0:02d}".format(lev)
                )
        ax1.set_xscale('log', basex=2)
        ax1.set_yscale('log', basey=10)
        ax1.set_xlabel("Nodes")
        ax1.set_ylabel("Speedup compared to 1 node level 14")
        ax1.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
            lambda x,y: str(int(x))
        ))
        ax1.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
            lambda x,y: str(int(x))
        ))
        ax1.yaxis.set_ticks_position('both')
        ax1.tick_params(axis='x', which='minor', bottom=False)

ax1.legend(loc='best', ncol=2)
ax1.plot([1,5400], [1,5400], color='grey', linestyle='-', linewidth=0.5)

for net, grp in df.groupby(['network']):
    for lev, grp2 in grp.groupby(['level']):
        r = 0.0 if net=='mpi' else 1.0
        g = 0.2
        b = (18-lev)/4
        colour = 'black' if net=='mpi' else 'blue'
        ax2.plot(grp2['nodes'],
                 grp2['grids/s'],
                 color=(r,g,b),
                 marker=markers[str(lev)],
                 label = net + " Level {0:02d}".format(lev)
                )
        ax2.set_xscale('log', basex=2)
        ax2.set_yscale('log', basey=10)
        ax2.set_xlabel("Nodes")
        ax2.set_ylabel("Grids/s compared to 1 node level 14")
        ax2.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
            lambda x,y: str(int(x))
        ))
        ax2.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
            lambda x,y: str(int(x))
        ))
        ax2.yaxis.set_ticks_position('both')

ax2.legend(loc='best', ncol=2)

plt.show()


# In[6]:


# create maps to access network/level/nodes and get speedup for cross referencing numbers
speedupmap = {}
for net, grp in df.groupby(['network']):
  speedupmap[net] = {}
  for lev, grp2 in grp.groupby(['level']):
    speedupmap[net][lev] = grp.set_index('nodes')['speedup'].to_dict()

df['speedupLF'] = df.apply(lambda row: (
    speedupmap['libfabric'][row.level][row.nodes]/
    speedupmap[row.network][row.level][row.nodes])
   , axis=1)

groups = df.groupby('network')
lf_mpi_speedup = groups.get_group('mpi')
print(lf_mpi_speedup)


# In[11]:


fig2, (bx1) = plt.subplots(nrows = 1, ncols = 1, figsize=(4,4), dpi= 80, facecolor='w', edgecolor='k')
for lev, grp in lf_mpi_speedup.groupby('level'):
    r = 0.0
    g = 0.2
    b = (18-lev)/4
    colour = 'black' if net=='mpi' else 'blue'
    bx1.plot(grp['nodes'],
             grp['speedupLF'],
             color=(r,g,b),
             marker=markers[str(lev)],
             label = " Level {0:02d}".format(lev)
            )
    bx1.set_xscale('log', basex=2)
    bx1.set_yscale('linear')
    bx1.set_xlabel("Nodes")
    bx1.set_ylabel("Speedup LF over MPI")
    bx1.set_ylim([0.5, 3.0])
    bx1.xaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
        lambda x,y: str(int(x))
    ))
    bx1.yaxis.set_major_formatter(matplotlib.ticker.FuncFormatter(
        lambda x,y: str(float(x))
    ))
    bx1.yaxis.set_ticks_position('both')
    bx1.legend(loc='best', ncol=1)


# In[12]:


# save this notebook as a raw python file as well please
get_ipython().system('jupyter nbconvert --to script generate-graph-data-from-table.ipynb')


# In[ ]:




