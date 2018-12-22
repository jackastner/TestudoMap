#! /usr/bin/env python

from osgeo import gdal
import sys

tif_file = sys.argv[1]
data = gdal.Open(tif_file, gdal.GA_ReadOnly)

histogram = {}
for row in data.GetRasterBand(1).ReadAsArray():
    for pixle in row:
        if pixle in histogram:
            histogram[pixle] += 1
        else:
            histogram[pixle] = 1

for e in sorted(histogram.items(), key=lambda e:e[1]):
    print('%10d : %6d' % e)
