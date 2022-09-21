import odb
import os
import datetime
import math
from math import gcd

class BookshelfToOdb:
    def __init__(
            self,
            opendbpy,
            opendb,
            cellPadding,
            modeFormat,
            plFile,
            nodeMapFile,
            netMapFile):
        self.odbpy = opendbpy
        self.odb = opendb
        self.year = datetime.datetime.now().year
        self.month = datetime.datetime.now().strftime("%b")
        self.day = datetime.datetime.now().day
        self.user = 'Seungwon Kim at University of California, San Diego (sek006@ucsd.edu)'
        self.modeFormat = modeFormat
        self.plFile = plFile
        self.nodeMapFile = nodeMapFile
        self.netMapFile = netMapFile

        self.chip = self.odb.getChip()
        self.block = self.chip.getBlock()
        self.siteWidth = self.block.getRows()[0].getSite().getWidth()
        self.siteHeight = self.block.getRows()[0].getSite().getHeight()
        print("siteWidth: %s" % self.siteWidth)
        print("siteHeight: %s" % self.siteHeight)
        print("GCD: %s" % gcd(self.siteWidth, self.siteHeight))
        #self.scaleFactor = self.targetScale / self.siteHeight
        self.scaleFactor = 1 / gcd(self.siteWidth, self.siteHeight)
        self.targetScale = self.scaleFactor * self.siteHeight
        print("Target siteHeight Scale: %s" % self.targetScale)
        print(
            "Scale Factor (Target siteHeight Scale / siteHeight): %s" %
            self.scaleFactor)

    def UpdatePl(self, dictNode):
        with open(self.plFile, 'r') as inFile:
            for line in inFile:
                if len(line) < 3:
                    continue
                if line.strip().startswith("UCLA"):
                    continue
                if line.strip().startswith("#"):
                    continue
                elif ':' not in line:
                    continue
                elif self.modeFormat == 'ISPD11' and line.split()[-1] == '/FIXED':
                    # Fixed insts.
                    # It has defined in the original ODB, so don't need to
                    # update.
                    continue
                elif (self.modeFormat == 'ISPD11' and line.split()[-1] == '/FIXED_NI') or (self.modeFormat != 'ISPD11' and line.split()[-1] == '/FIXED'):
                    # Fixed insts + boundary terminals
                    instMappedName = line.split()[0]
                    instLlx = float(line.split()[1])
                    instLly = float(line.split()[2])
                    instOrigName = dictNode[instMappedName]
                    #print(instOrigName, instMappedName)
                    # print(self.block.findBTerm(instOrigName))
                    bTerm = self.block.findBTerm(instOrigName)
                    if bTerm is not None:
                        bPins = bTerm.getBPins()
                        for bPin in bPins:

                            boxes = bPin.getBoxes()
                            # TODO: do not support multiple boxes
                            assert(len(boxes) == 1)
                            for box in boxes:
                                bTermWidth = int(box.xMax() - box.xMin())
                                bTermHeight = int(box.yMax() - box.yMin())
                                #print(bTermWidth, bTermHeight)

                                layerBPin = box.getTechLayer()
                                bPin.destroy(bPin)
                                bPin.create(bTerm)
                                bPinLlx = int(instLlx / self.scaleFactor)
                                bPinLly = int(instLly / self.scaleFactor)
                                bPinUrx = int(
                                    instLlx / self.scaleFactor) + int(bTermWidth)
                                bPinUry = int(
                                    instLly / self.scaleFactor) + int(bTermHeight)
                                box.create(
                                    bPin, layerBPin, bPinLlx, bPinLly, bPinUrx, bPinUry)
                                # print(bPinLlx,bPinLly,bPinUrx,bPinUry)
                                bPin.setPlacementStatus('PLACED')
                                # TODO: Snapping to on-track?
                    continue
                else:
                    instMappedName = line.split()[0]
                    instLlx = float(line.split()[1])
                    instLly = float(line.split()[2])
                    instOrigName = dictNode[instMappedName]
                    #print(instOrigName, instMappedName)
                    # print(self.block.findInst(instOrigName))

                    instOrig = self.block.findInst(instOrigName)
                    instOrigWidth = instOrig.getMaster().getWidth()
                    instOrigHeight = instOrig.getMaster().getHeight()

                    instOrigLlx = int(instLlx / self.scaleFactor)
                    instOrigLly = int(instLly / self.scaleFactor)

                    instOrig.setLocation(instOrigLlx, instOrigLly)
                    instOrig.setPlacementStatus('PLACED')
                    # TODO: Snapping to on-track?

    def DecodeMap(self):
        dictNode = dict()
        with open(self.nodeMapFile, 'r') as inFile:
            for line in inFile:
                origName = line.split()[0]
                mappedName = line.split()[1]
                dictNode[mappedName] = origName

        return dictNode

    def UpdateOdb(self):
        dictNode = self.DecodeMap()
        self.UpdatePl(dictNode)
        os.path.exists
        dbName = './output/%s_pad%s_%s/%s_pad%s_%s_mapped.odb' % (
            odbName, cellPadding, modeFormat, odbName, cellPadding, modeFormat)
        defName = './output/%s_pad%s_%s/%s_mapped.def' % (
            odbName, cellPadding, modeFormat, odbName)

        if os.path.exists(dbName):
            os.remove(dbName)
        if os.path.exists(defName):
            os.remove(defName)

        odb.write_db(
            self.odb,
            './%s_pad%s_%s/%s_pad%s_%s_mapped.odb' %
            (odbName,
             cellPadding,
             modeFormat,
             odbName,
             cellPadding,
             modeFormat))
        odb.write_def(
            self.block,
            './%s_pad%s_%s/%s_mapped.def' %
            (odbName,
             cellPadding,
             modeFormat,
             odbName))


if __name__ == "__main__":

    ################ Settings #################
    odbPath = './odbFiles'

    # The number of sites for cell padding (+left, +right)
    cellPaddings = [0, 1, 2, 3, 4]

    # Format list of Bookshelf to be created.
    modeFormats = ['ISPD04', 'ISPD11']

    # OpenDB list for Bookshelf generation
    odbList = [
        'sky130hd_ISPD2006_adaptec1',
    ]
    ###########################################

    for modeFormat in modeFormats:
        for cellPadding in cellPaddings:
            for odbName in odbList:
                plFile = './output/%s_pad%s_%s/%s_pad%s_%s_mapped.ntup.pl' % (
                    odbName, cellPadding, modeFormat, odbName, cellPadding, modeFormat)
                nodeMapFile = './output/%s_pad%s_%s/%s_pad%s_%s_mapped.nodemap' % (
                    odbName, cellPadding, modeFormat, odbName, cellPadding, modeFormat)
                netMapFile = './output/%s_pad%s_%s/%s_pad%s_%s_mapped.netmap' % (
                    odbName, cellPadding, modeFormat, odbName, cellPadding, modeFormat)
                db = odb.dbDatabase.create()
                print(odb)
                odb.read_db(db, '%s/%s.odb' % (odbPath, odbName))
                bs = BookshelfToOdb(
                    opendbpy=odb,
                    opendb=db,
                    cellPadding=cellPadding,
                    modeFormat=modeFormat,
                    plFile=plFile,
                    nodeMapFile=nodeMapFile,
                    netMapFile=netMapFile)
                bs.UpdateOdb()
