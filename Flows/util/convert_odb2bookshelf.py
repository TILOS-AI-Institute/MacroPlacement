#import opendbpy as odb
import odb
import os
import datetime
import math
from math import gcd
# import namemap


class OdbToBookshelf:
    def __init__(
            self,
            opendbpy,
            opendb,
            cellPadding,
            modeFormat,
            layerCapacity):
        self.odbpy = opendbpy
        self.odb = opendb
        self.year = datetime.datetime.now().year
        self.month = datetime.datetime.now().strftime("%b")
        self.day = datetime.datetime.now().day
        self.user = 'Seungwon Kim at University of California, San Diego (sek006@ucsd.edu)'

        # This target Scale is required because academic placer uses smaller size of numbers than commercial benchmark.
        # Scale down relatively so that siteHeight is to be a scale factor
        # value.

        self.modeFormat = modeFormat

        # This input file is for global routing layer adjustment
        # By default, the fastroute.tcl.
        self.fileGR = layerCapacity

        self.chip = self.odb.getChip()
        self.block = self.chip.getBlock()
        self.units = self.block.getDefUnits()
        self.nets = self.block.getNets()
        self.tech = self.odb.getTech()
        self.insts = self.block.getInsts()
        self.BTerms = self.block.getBTerms()
        self.blocks = self.block.getBlockages()
        self.numInsts = len(self.insts)
        self.numBTerms = len(self.BTerms)
        # for bterm in self.BTerms:
        #  pins = bterm.getBPins()
        #  if len(pins)==0:
        #    self.numBTerms = self.numBTerms-1
        self.numNodes = self.numInsts + self.numBTerms

        # Suppose that the core's LL and UR corners are not fragmented rows.
        self.xMinCore = self.block.getRows()[0].getBBox().xMin()
        self.xMaxCore = self.block.getRows()[-1].getBBox().xMax()
        self.yMinCore = self.block.getRows()[0].getBBox().yMin()
        self.yMaxCore = self.block.getRows()[-1].getBBox().yMax()

        self.siteWidth = self.block.getRows()[0].getSite().getWidth()
        self.siteHeight = self.block.getRows()[0].getSite().getHeight()
        self.siteSpacing = self.block.getRows()[0].getSpacing()
        print("core area (llx lly urx ury): %s %s  %s %s" %
              (self.xMinCore, self.yMinCore, self.xMaxCore, self.yMaxCore))
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
        print(
            "scaled core area (llx lly urx ury): %s %s  %s %s" %
            (self.xMinCore *
             self.scaleFactor,
             self.yMinCore *
             self.scaleFactor,
             self.xMaxCore *
             self.scaleFactor,
             self.yMaxCore *
             self.scaleFactor))
        print("scaled siteWidth: %s" % (self.siteWidth * self.scaleFactor))
        print("scaled siteHeight: %s" % (self.siteHeight * self.scaleFactor))
        self.xMinCore = self.xMinCore * self.scaleFactor
        self.xMaxCore = self.xMaxCore * self.scaleFactor
        self.yMinCore = self.yMinCore * self.scaleFactor
        self.yMaxCore = self.yMaxCore * self.scaleFactor
        self.siteWidth = self.siteWidth * self.scaleFactor
        self.siteHeight = self.siteHeight * self.scaleFactor
        self.siteSpacing = self.siteSpacing * self.scaleFactor
        self.cellPad = int(self.siteWidth) * cellPadding

        self.offsetX = self.siteHeight - (self.xMinCore % self.siteHeight)
        self.offsetY = self.siteHeight - (self.yMinCore % self.siteHeight)
        print('OffsetCoordi : %s %s' % (self.offsetX, self.offsetY))
        self.unitY = self.siteHeight / self.targetScale
        self.unitX = self.unitY
        print('unit X Y : %s %s' % (self.unitX, self.unitY))

        self.signalLayers = []
        self.layerName = []
        self.layerPitch = []
        self.layerMinWireWidth = []
        self.layerMinWireSpacing = []
        self.viaSpacing = []
        for self.layer in self.tech.getLayers():
            if self.layer.getType() == 'ROUTING':
                self.signalLayers.append(self.layer)
                self.layerName.append(self.layer.getName())
                self.layerPitch.append(self.layer.getPitch())
                # Currently, bookshelf always use '1' MinWireWidth, '0'
                # MinWireSpacing and ViaSpacing
                self.layerMinWireWidth.append(100)
                # self.layerMinWireWidth.append(self.layer.getPitch())
                self.layerMinWireSpacing.append(0)
                self.viaSpacing.append(0)

    def WriteAux(self, bsName):
        print("Writing .aux")
        f = open('./output/%s/%s.aux' % (bsName, bsName), 'w')
        f.write(
            'RowBasedPlacement : %s.nodes %s.nets %s.wts %s.pl %s.scl %s.shapes %s.route' %
            (bsName, bsName, bsName, bsName, bsName, bsName, bsName))
        f.close()

    def WriteNodes(self, bsName):
        print("Writing .nodes")
        f = open('./output/%s/%s.nodes' % (bsName, bsName), 'w')
        f.write('UCSD nodes 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n' % self.user)
        f.write('\n')
        cntTerms = 0
        for inst in self.insts:
            if inst.isFixed():
                cntTerms = cntTerms + 1
        numTerms = self.numBTerms + cntTerms
        f.write('NumNodes      :  %s\n' %
                (self.numNodes + len(self.dictFakeCells)))
        f.write('NumTerminals  :  %s\n' % (numTerms + len(self.dictFakeCells)))
        f.write('\n')
        for inst in self.insts:
            instWidth = inst.getBBox().getDX()
            instHeight = inst.getBBox().getDY()
            if inst.isFixed():
                #f.write('%s%s%s        terminal\n'%(inst.getName().rjust(15), str('%0.4f'%(instWidth * self.scaleFactor)).rjust(15), str('%0.4f'%(instHeight * self.scaleFactor)).rjust(15)))
                f.write('%s%s%s        terminal\n' %
                        (inst.getName().rjust(15), str('%i' %
                                                       (instWidth * self.scaleFactor)).rjust(15), str('%i' %
                                                                                                      (instHeight * self.scaleFactor)).rjust(15)))
            else:
                #f.write('%s%s%s\n'%(inst.getName().rjust(15), str('%0.4f'%(instWidth * self.scaleFactor)).rjust(15), str('%0.4f'%(instHeight * self.scaleFactor)).rjust(15)))
                f.write('%s%s%s\n' %
                        (inst.getName().rjust(15), str('%i' %
                                                       ((instWidth *
                                                         self.scaleFactor) +
                                                        (self.cellPad *
                                                         2))).rjust(15), str('%i' %
                                                                             (instHeight *
                                                                              self.scaleFactor)).rjust(15)))
        for bterm in self.BTerms:
            pins = bterm.getBPins()
            # TODO: do not support multiple pins for one terminal
            #assert(len(pins) == 1)
            for pin in pins:
                boxes = pin.getBoxes()
                # TODO: do not support multiple boxes
                assert(len(boxes) == 1)
                for box in boxes:
                    btermWidth = box.xMax() - box.xMin()
                    btermHeight = box.yMax() - box.yMin()
                    #f.write('%s%s%s        terminal_NI\n'%(bterm.getName().rjust(15), str('%0.4f'%(btermWidth * self.scaleFactor)).rjust(15), str('%0.4f'%(btermHeight * self.scaleFactor)).rjust(15)))
                    #f.write('%s%s%s        terminal_NI\n'%(bterm.getName().rjust(15), str('%i'%(btermWidth * self.scaleFactor)).rjust(15), str('%i'%(btermHeight * self.scaleFactor)).rjust(15)))
                    if self.modeFormat == 'ISPD11':
                        f.write(
                            '%s%s%s        terminal_NI\n' %
                            (bterm.getName().rjust(15),
                             str('1').rjust(15),
                                str('1').rjust(15)))
                    else:
                        f.write(
                            '%s%s%s        terminal\n' %
                            (bterm.getName().rjust(15),
                             str('0').rjust(15),
                                str('0').rjust(15)))
            if len(pins) == 0:
                #f.write('%s%s%s        terminal_NI\n'%(bterm.getName().rjust(15), str('0.000000').rjust(15), str('0.000000').rjust(15)))
                if self.modeFormat == 'ISPD11':
                    f.write(
                        '%s%s%s        terminal_NI\n' %
                        (bterm.getName().rjust(15),
                         str('1').rjust(15),
                            str('1').rjust(15)))
                else:
                    f.write(
                        '%s%s%s        terminal\n' %
                        (bterm.getName().rjust(15),
                         str('0').rjust(15),
                            str('0').rjust(15)))

        for key, values in self.dictFakeCells.items():
            f.write(
                '%s%s%s        terminal\n' %
                (key.rjust(15), str(
                    '%i' %
                    (values[2])).rjust(15), str(
                    '%i' %
                    (self.siteHeight)).rjust(15)))

        f.close()

    def WriteRoute(self, bsName):
        print("Writing .route")
        f = open('./output/%s/%s.route' % (bsName, bsName), 'w')
        f.write('UCSD route 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n' % self.user)

        layerVcap = []
        layerHcap = []

        # Grid should be calculated with M2 Pitch x 15
        tileSize = self.layerPitch[1] * 15
        #tileSize = self.layerPitch[1]*20
        for i, layer in enumerate(self.signalLayers):
            if layer.getType() == 'ROUTING':
                if layer.getDirection() == 'VERTICAL':
                    layerVcap.append(
                        round(
                            tileSize /
                            self.layerPitch[i] *
                            self.layerMinWireWidth[i]))
                    layerHcap.append(0)
                elif layer.getDirection() == 'HORIZONTAL':
                    layerHcap.append(
                        round(
                            tileSize /
                            self.layerPitch[i] *
                            self.layerMinWireWidth[i]))
                    layerVcap.append(0)
                else:
                    print('Routing direction error: neither VERTICAL or HORIZONTAL')
                    exit()

        # Layer Capacity Adjustment
        # Currently, it supports only the capability change of the entire
        # region of each layers.
        fgr = open(self.fileGR, 'r')
        lines = fgr.readlines()
        fgr.close()
        layerAdjustNames, layerAdjustValues = [], []
        for line in lines:
            if line.startswith('set_global_routing_layer_adjustment'):
                layerRange = line.split()[1]
                if '-' in layerRange:
                    bottomLayerAdjust = layerRange.split('-')[0]
                    topLayerAdjust = layerRange.split('-')[1]
                    for i in range(
                            self.layerName.index(bottomLayerAdjust),
                            self.layerName.index(topLayerAdjust)):
                        layerAdjustNames.append(self.layerName[i])
                        layerAdjustValues.append(line.split()[2])
                else:
                    layerAdjustNames.append(layerRange)
                    layerAdjustValues.append(line.split()[2])
        print(layerAdjustNames)
        print(layerAdjustValues)

        strLayerVcap = ''
        strLayerHcap = ''
        strLayerMinWireWidth = ''
        strLayerMinWireSpacing = ''
        strViaSpacing = ''
        for i, layer in enumerate(self.signalLayers):
            if layer.getName() in layerAdjustNames:
                layerIdx = layerAdjustNames.index(layer.getName())
                reducedVcap = int(
                    float(
                        layerVcap[i]) *
                    float(
                        layerAdjustValues[layerIdx]))
                reducedHcap = int(
                    float(
                        layerHcap[i]) *
                    float(
                        layerAdjustValues[layerIdx]))
            else:
                reducedVcap = layerVcap[i]
                reducedHcap = layerHcap[i]

            strLayerVcap += str(reducedVcap).rjust(8)
            strLayerHcap += str(reducedHcap).rjust(8)
            strLayerMinWireWidth += str(self.layerMinWireWidth[i]).rjust(8)
            strLayerMinWireSpacing += str(self.layerMinWireSpacing[i]).rjust(8)
            strViaSpacing += str(self.viaSpacing[i]).rjust(8)

        print(layerHcap)
        print(layerVcap)
        print(self.layerName)
        print(self.layerPitch)

        gridOrigX = (0 + self.offsetX) / (self.unitX)
        gridOrigY = (0 + self.offsetY) / (self.unitY)
        print('orig (float): %s %s' % (gridOrigX, gridOrigY))
        gridOrigX = int(gridOrigX + 0.5)
        gridOrigY = int(gridOrigY + 0.5)
        print('orig (int) : %s %s' % (gridOrigX, gridOrigY))

        widthCore = (self.xMaxCore - self.xMinCore) / self.scaleFactor
        heightCore = (self.yMaxCore - self.yMinCore) / self.scaleFactor
        widthDie = (self.block.getBBox().xMax() - self.block.getBBox().xMin())
        heightDie = (self.block.getBBox().yMax() - self.block.getBBox().yMin())
        gridX = math.ceil(widthDie / tileSize)
        gridY = math.ceil(heightDie / tileSize)
        #gridX = math.ceil(widthCore / tileSize)
        #gridY = math.ceil(heightCore / tileSize)
        numLayers = len(self.layerName)

        # Porosity for routing blockages
        # Zero implies the blockage completely blocks
        # overlapping routing tracks. Default = 0
        blockagePorosity = 0

        f.write('Grid'.ljust(19) + ': %s %s %s\n' % (gridX, gridY, numLayers))

        f.write('VerticalCapacity'.ljust(19) + ': %s\n' % strLayerVcap)
        f.write('HorizontalCapacity'.ljust(19) + ': %s\n' % strLayerHcap)
        f.write('MinWireWidth'.ljust(19) + ': %s\n' % strLayerMinWireWidth)
        f.write('MinWireSpacing'.ljust(19) + ': %s\n' % strLayerMinWireSpacing)
        f.write('ViaSpacing'.ljust(19) + ': %s\n' % strViaSpacing)
        f.write('GridOrigin'.ljust(19) + ': %s %s\n' % (int(gridOrigX *
                self.scaleFactor), int(gridOrigY * self.scaleFactor)))
        f.write('TileSize'.ljust(19) + ': %s %s\n' % (int(math.ceil(tileSize *
                self.scaleFactor)), int(math.ceil(tileSize * self.scaleFactor))))
        f.write('BlockagePorosity'.ljust(19) + ': %s\n\n' % (blockagePorosity))

        numNiTerminals = self.numBTerms
        for bterm in self.BTerms:
            pins = bterm.getBPins()
            if len(pins) == 0:
                numNiTerminals = numNiTerminals - 1
        f.write('NumNiTerminals'.ljust(19) + ': %s\n' % numNiTerminals)
        for bterm in self.BTerms:
            pins = bterm.getBPins()
            for pin in pins:
                boxes = pin.getBoxes()
                for box in boxes:
                    terminalNiLayer = int(
                        self.layerName.index(
                            box.getTechLayer().getName())) + 1
                    f.write(
                        '  %s' %
                        (bterm.getName()) +
                        ' %s\n' %
                        (terminalNiLayer))
            if len(pins) == 0:
                pass
                #f.write('  %s'%(bterm.getName())+' %s\n'%(terminalNiLayer))

        cntBlockages = 0

        strListBlocks = []
        for inst in self.insts:
            if inst.isFixed():
                blockName = inst.getName()
                listLayer = []
                for obs in inst.getMaster().getObstructions():
                    curLayer = obs.getTechLayer()
                    if curLayer.getType() == 'ROUTING':
                        listLayer.append(
                            self.layerName.index(
                                curLayer.getName()))
                listLayer = sorted(list(set(listLayer)))
                if len(listLayer) == 0:
                    # Do not write if the OBS is in M1 only.
                    continue
                if len(listLayer) == 1 and listLayer[0] == 0:
                    # Do not write if the OBS is in M1 only.
                    continue
                    #listLayer = [1]
                    #strBlockLayers = ' 1'
                cntBlockages = cntBlockages + 1
                strBlockLayers = ''
                for i in listLayer:
                    strBlockLayers = strBlockLayers + ' ' + str(i + 1)
                strListBlocks.append(
                    '  %s  %s%s\n' %
                    (blockName, len(listLayer), strBlockLayers))

        for block in self.blocks:
            if block.getInstance() is not None:
                # Do not write if the OBS is in M1 only.
                continue
                #blockName = block.getInstance().getName()
                #topBlockLayer = str(1)
                #blockLayers = ' '+str(1)
                #f.write('  %s  %s%s\n'%(blockName, topBlockLayer, blockLayers))

        numBlockages = len(self.block.getBlockages()) + cntBlockages
        # below three lines are commented out because .shape has a scaling mismatch, overlapping problem with bookshelf grid.
        # only rectangular boundary box can be considered for the shape.
        f.write('NumBlockageNodes'.ljust(19) + ': 0\n')
        #f.write('NumBlockageNodes'.ljust(19)+': %s\n'%cntBlockages)
        # for string in strListBlocks:
        #  f.write('%s'%string)

        f.write('NumEdgeCapacityAdjustments  : 0\n')

        #numEdgeCapacity = len(layerAdjustNames) * (gridX * gridY * 2 - (gridX+gridY))
        #f.write('NumEdgeCapacityAdjustments  : %s\n'%numEdgeCapacity)
        # for i in range(0,len(layerAdjustNames)):
        #  layerIdx = self.layerName.index(layerAdjustNames[i])
        #  curVcap = float(layerAdjustValues[i])*float(layerVcap[layerIdx])
        #  curHcap = float(layerAdjustValues[i])*float(layerHcap[layerIdx])
        #  curAdjustValue = int(max(curVcap, curHcap))
        #  for j in range(0,gridX):
        #    for k in range(0,gridY):
        #      if k+1 < gridY and j+1 < gridX:
        #        strLayerAdjust = '  %s  %s  %s  %s  %s  %s  %s\n'%(j,k,layerIdx+1, j, k+1, layerIdx+1, curAdjustValue)
        #        f.write(strLayerAdjust)
        #        strLayerAdjust = '  %s  %s  %s  %s  %s  %s  %s\n'%(j,k,layerIdx+1, j+1, k, layerIdx+1, curAdjustValue)
        #        f.write(strLayerAdjust)
        #      elif k+1 == gridY and j+1 < gridX:
        #        strLayerAdjust = '  %s  %s  %s  %s  %s  %s  %s\n'%(j,k,layerIdx+1, j+1, k, layerIdx+1, curAdjustValue)
        #        f.write(strLayerAdjust)
        #      elif k+1 < gridY and j+1 == gridX:
        #        strLayerAdjust = '  %s  %s  %s  %s  %s  %s  %s\n'%(j,k,layerIdx+1, j, k+1, layerIdx+1, curAdjustValue)
        #        f.write(strLayerAdjust)
        f.close()

    def WriteWts(self, bsName):
        print("Writing .wts")
        f = open('./output/%s/%s.wts' % (bsName, bsName), 'w')
        f.write('UCSD wts 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n\n' % self.user)
        f.close()

    def WriteNets(self, bsName):
        print("Writing .nets")
        f = open('./output/%s/%s.nets' % (bsName, bsName), 'w')
        f.write('UCSD nets 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n\n' % self.user)

        # NumNets and NumPins
        cntNets = 0
        numPins = 0
        for net in self.nets:
            netDegree = net.getTermCount()
            if net.isSpecial() != 1 and netDegree > 1:
                cntNets = cntNets + 1
                numPins = numPins + net.getTermCount()

        f.write('NumNets  :  %s\n' % cntNets)
        f.write('NumPins  :  %s\n\n' % numPins)

        for net in self.nets:
            if net.isSpecial() == 1:
                continue
            netDegree = net.getTermCount()
            if netDegree < 2:
                continue
            netName = net.getName()
            f.write('NetDegree  :  %s    %s\n' % (netDegree, netName))
            # for boundary pins (PI, PO, others)
            for bPin in net.getBTerms():
                instName = bPin.getName()
                bPinDirection = bPin.getIoType()
                if bPinDirection == 'INPUT':
                    bPinDirection = 'I'
                elif bPinDirection == 'OUTPUT':
                    bPinDirection = 'O'
                else:
                    iPinDirection = 'B'

                # Pin offset. X,Y offset for PI, PO is 0,0.
                bPinXOffset = 0
                bPinYOffset = 0

                #f.write('%s   %s  :%s%s\n'%(str(instName).rjust(15), bPinDirection, str('%0.4f'%(bPinXOffset * self.scaleFactor)).rjust(12), str('%0.4f'%(bPinYOffset * self.scaleFactor)).rjust(12)))
                f.write('%s   %s  :%s%s\n' %
                        (str(instName).rjust(15), bPinDirection, str('%i' %
                                                                     (bPinXOffset * self.scaleFactor)).rjust(12), str('%i' %
                                                                                                                      (bPinYOffset * self.scaleFactor)).rjust(12)))

            # for instance pins
            for iPin in net.getITerms():
                instName = iPin.getInst().getName()
                iPinDirection = iPin.getIoType()
                if iPinDirection == 'INPUT':
                    iPinDirection = 'I'
                elif iPinDirection == 'OUTPUT':
                    iPinDirection = 'O'
                else:
                    iPinDirection = 'B'

                instXLoc, instYLoc = iPin.getInst().getLocation()
                instXCen = float(
                    instXLoc) + float(iPin.getInst().getMaster().getWidth()) / float(2)
                instYCen = float(
                    instYLoc) + float(iPin.getInst().getMaster().getHeight()) / float(2)
                isShape, iPinXCen, iPinYCen, = iPin.getAvgXY()
                xx = 0.0000
                yy = 0.0000
                tt = 0
                nn = 0
                instOrigX, instOrigY = iPin.getInst().getOrigin()
                instOrig = odb.Point(instOrigX, instOrigY)
                instOrient = iPin.getInst().getOrient()
                t = odb.dbTransform(instOrient, instOrig)
                tx = 0
                ty = 0
                for mPin in iPin.getMTerm().getMPins():
                    for box in mPin.getGeometry():
                        ## Shape ########
                        # Example:
                        #   a----------b
                        #   |          |
                        #   |          |
                        #   |          |
                        #   c----------d
                        #
                        # "getGeomShape().getPoints()" --> a, b, c, d, a
                        #
                        #tx = 0
                        #ty = 0
                        # t = odb.dbTransform(instOrient, instOrig)
                        # Calculate center of pin
                        # for pp in box.getGeomShape().getPoints()[:-1]:
                        #     t.apply(pp)
                        #     tx = tx + float(pp.getX())
                        #     ty = ty + float(pp.getY())
                        #     #print("tx, ty = %s %s"%(pp.getX()/1000,pp.getY()/1000))
                        #     tt = tt + 1
                        rr = odb.Rect(box.xMin(), box.yMin(), box.xMax(), box.yMax())
                        for pp in rr.getPoints():
                            t.apply(pp)
                            # print('Hi ',type(pp), type(box))
                        # print('Here ', box.xMin(), box.yMin(), box.xMax(), box.yMax())
                        # 
                        # print(pp)
                        # # box.getBox(pp)
                        # print(type(pp))
                        # t.apply(pp)
                            tt += 1
                            tx += pp.getX()
                            ty += pp.getY()

                iPinXCen = float(tx) / float(tt)
                iPinYCen = float(ty) / float(tt)

                #print("iPinCens: %s %s"%(iPinXCen, iPinYCen))
                #print("instCens: %s %s"%(instXCen, instYCen))
                iPinXOffset = (float(iPinXCen) - instXCen)
                iPinYOffset = (float(iPinYCen) - instYCen)
                #print(iPinXOffset, iPinYOffset)

                #f.write('%s   %s  :%s%s\n'%(str(instName).rjust(15), iPinDirection, str('%0.4f'%(iPinXOffset * self.scaleFactor)).rjust(12), str('%0.4f'%(iPinYOffset * self.scaleFactor)).rjust(12)))
                f.write('%s   %s  :%s%s\n' %
                        (str(instName).rjust(15), iPinDirection, str('%i' %
                                                                     (iPinXOffset * self.scaleFactor)).rjust(12), str('%i' %
                                                                                                                      (iPinYOffset * self.scaleFactor)).rjust(12)))

        f.close()

    def WritePl(self, bsName):
        print("Writing .pl")
        f = open('./output/%s/%s.pl' % (bsName, bsName), 'w')
        f.write('UCSD pl 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n\n' % self.user)

        # Orientation of all the nodes will always be N (default)
        for inst in self.insts:
            instLocX, instLocY = inst.getLocation()
            scaledInstLocX = instLocX
            scaledInstLocY = instLocY
            if inst.isFixed() == 0:
                #f.write('%s'%inst.getName() + '\t%0.4f\t%0.4f : N\n'%((scaledInstLocX * self.scaleFactor)-self.cellPad,scaledInstLocY * self.scaleFactor))
                f.write(
                    '%s' %
                    inst.getName() +
                    '\t%i\t%i : N\n' %
                    (scaledInstLocX *
                     self.scaleFactor,
                     scaledInstLocY *
                     self.scaleFactor))
            else:
                #f.write('%s'%inst.getName() + '\t%0.4f\t%0.4f : N /FIXED\n'%(scaledInstLocX * self.scaleFactor,scaledInstLocY * self.scaleFactor))
                f.write(
                    '%s' %
                    inst.getName() +
                    '\t%i\t%i : N /FIXED\n' %
                    (scaledInstLocX *
                     self.scaleFactor,
                     scaledInstLocY *
                     self.scaleFactor))
        for bterm in self.BTerms:
            pins = bterm.getBPins()
            for pin in pins:
                pinLocX = pin.getBBox().xMin()
                pinLocY = pin.getBBox().yMin()
                #f.write('%s'%bterm.getName() + '\t%0.4f\t%0.4f : N /FIXED_NI\n'%(pinLocX * self.scaleFactor,pinLocY * self.scaleFactor))
                f.write(
                    '%s' %
                    bterm.getName() +
                    '\t%i\t%i : N /FIXED_NI\n' %
                    (pinLocX *
                     self.scaleFactor,
                     pinLocY *
                     self.scaleFactor))
            if len(pins) == 0:
                #f.write('%s'%bterm.getName() + '\t0.0000\t0.0000 : N /FIXED_NI\n')
                f.write('%s' % bterm.getName() + '\t0\t0 : N /FIXED_NI\n')

        for key, values in self.dictFakeCells.items():
            f.write(
                '%s' %
                key +
                '\t%i\t%i : N /FIXED\n' %
                (values[0],
                 values[1]))

        f.close()

    def WriteScl(self, bsName):
        print("Writing .scl")
        f = open('./output/%s/%s.scl' % (bsName, bsName), 'w')
        f.write('UCSD scl 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n\n' % self.user)

        self.numRows = int((self.yMaxCore - self.yMinCore) / self.siteHeight)
        self.numSites = int((self.xMaxCore - self.xMinCore) / self.siteWidth)
        f.write('NumRows :  \t%s\n\n' % self.numRows)
        #f.write('NumRows :  \t%s\n\n'%len(self.block.getRows()))
        for curRow in range(self.numRows):
            f.write('CoreRow Horizontal\n')
            f.write('  Coordinate     :   %i\n' %
                    ((curRow) * self.siteHeight + self.yMinCore))
            f.write('  Height         :   %i\n' % (self.siteHeight))
            f.write('  Sitewidth      :    %i\n' % (self.siteWidth))
            f.write('  Sitespacing    :    %i\n' % (self.siteSpacing))
            if (curRow + 1) % 2 == 0:
                f.write('  Siteorient     :    MX\n')
            else:
                f.write('  Siteorient     :    R0\n')
            f.write('  Sitesymmetry   :    True\n')
            f.write(
                '  SubrowOrigin   :    %i\tNumSites  :  %s\n' %
                (self.xMinCore, self.numSites))
            f.write('End\n')
        f.close()

        # Store the fixed fake cells for fragmented rows.
        xMaxCandi = {}
        xMinCandi = {}
        for rowIdx, row in enumerate(self.block.getRows()):
            # if ((row.getBBox().xMin() * self.scaleFactor) != self.xMinCore) and (self.block.getRows()[rowIdx-1].getBBox().yMin() != row.getBBox().yMin()):
            #    xMinFakeCell = self.xMinCore
            #    xMaxFakeCell = self.block.getRows()[rowIdx+1].getBBox().xMin() * self.scaleFactor
            #    if self.block.getRows()[rowIdx+1].getBBox().yMin() != row.getBBox().yMin():
            #        print("1")
            #        xMaxFakeCell = self.xMaxCore
            #    print(xMinFakeCell,  xMaxFakeCell)
            #    continue

            # if (row.getBBox().xMax() * self.scaleFactor) != self.xMaxCore:
            #    xMinFakeCell = row.getBBox().xMax()*self.scaleFactor
            #    xMaxFakeCell = self.block.getRows()[rowIdx+1].getBBox().xMin() * self.scaleFactor
            #    if self.block.getRows()[rowIdx+1].getBBox().yMin() != row.getBBox().yMin():
            #        print(self.block.getRows()[rowIdx+1].getBBox().yMin(), row.getBBox().yMin())
            #        xMaxFakeCell = self.xMaxCore
            #    print(xMinFakeCell,  xMaxFakeCell)
            #    continue
            if (row.getBBox().xMin() *
                self.scaleFactor == self.xMinCore) and (row.getBBox().xMax() *
                                                        self.scaleFactor == self.xMaxCore):
                continue
            if row.getBBox().xMin() * self.scaleFactor != self.xMinCore:
                xMaxCandi.setdefault(
                    row.getBBox().yMin() * self.scaleFactor, [])
                xMaxCandi[row.getBBox().yMin() *
                          self.scaleFactor].append(row.getBBox().xMin() *
                                                   self.scaleFactor)
                pass
            if row.getBBox().xMax() * self.scaleFactor != self.xMaxCore:
                xMinCandi.setdefault(
                    row.getBBox().yMin() * self.scaleFactor, [])
                xMinCandi[row.getBBox().yMin() *
                          self.scaleFactor].append(row.getBBox().xMax() *
                                                   self.scaleFactor)
                pass

        #print("xMax candi: %s"%xMaxCandi)
        #print("xMin candi: %s"%xMinCandi)
        # self.dictFakeCells key: fakecell name, values: [llx, lly, width]
        self.dictFakeCells = {}
        countFakeCells = 0
        for key, values in xMinCandi.items():
            xMinCandi[key].sort()
            xMaxCandi[key].sort()
            #print(key, values, xMaxCandi[key])
            if values[0] > xMaxCandi[key][0]:
                xMinCandi[key].append(self.xMinCore)
            if values[-1] > xMaxCandi[key][-1]:
                xMaxCandi[key].append(self.xMaxCore)
            for idx, value in enumerate(values):
                #print(value, xMaxCandi[key][idx])

                fakeCellName = "fk%s" % countFakeCells
                countFakeCells = countFakeCells + 1
                self.dictFakeCells.setdefault(fakeCellName, [])
                fakeCellWidth = xMaxCandi[key][idx] - value
                self.dictFakeCells[fakeCellName] = [value, key, fakeCellWidth]
        # print(self.dictFakeCells)

    def WriteShapes(self, bsName):
        print("Writing .shapes")
        f = open('./output/%s/%s.shapes' % (bsName, bsName), 'w')
        f.write('UCSD shapes 1.0\n')
        f.write(
            '# Created  :  %s  %s %s\n' %
            (self.month, self.day, self.year))
        f.write('# User     :  %s\n\n' % self.user)

        # it is commented out because .shape has a scaling mismatch, overlapping problem with bookshelf grid.
        # only rectangular boundary box can be considered for the shape.
        #cntNonRectNodes = 0
        #nestedListBlockShapes = []
        # for inst in self.insts:
        #  if inst.isFixed():
        #    listStrBlockShapes = []
        #    listBlockShapes = []
        #    blockName = inst.getName()
        #    instObstructions = inst.getMaster().getObstructions()
        #    listLayer = []
        #    for obs in instObstructions:
        #      curLayer = obs.getTechLayer()
        #      if curLayer.getType() == 'ROUTING':
        #        listLayer.append(self.layerName.index(curLayer.getName()))
        #    listLayer = sorted(list(set(listLayer)))
        #    if len(listLayer)==0:
        #      #Do not write if the OBS is in M1 only.
        #      continue
        #    if len(listLayer)==1 and listLayer[0]==0:
        #      #Do not write if the OBS is in M1 only.
        #      continue
        #    if len(instObstructions)!=0:
        #      cntNonRectNodes = cntNonRectNodes+1
        #      listStrBlockShapes.append(blockName)
        #      for i, obs in enumerate(instObstructions):
        #        curLayer = obs.getTechLayer()
        #        if curLayer.getType() == 'ROUTING':
        #          #f.write('  Shape_%s'%i+' %s %s\t%s %s\n'%(obs.xMin(),obs.yMin(),obs.getDX(),obs.getDY()))
        #          #listStrBlockShapes.append(str('  Shape_%s'%i+' %0.4f %0.4f\t%0.4f %0.4f\n'%(obs.xMin()* self.scaleFactor,obs.yMin()* self.scaleFactor,obs.getDX()* self.scaleFactor,obs.getDY()* self.scaleFactor)))
        #          #listStrBlockShapes.append(str('  Shape_%s'%i+' %i %i\t%i %i\n'%(math.ceil(obs.xMin() * self.scaleFactor),math.ceil(obs.yMin() * self.scaleFactor),math.ceil(obs.getDX() * self.scaleFactor),math.ceil(obs.getDY() * self.scaleFactor))))
        #          #listStrBlockShapes.append(str('  Shape_%s'%i+' %i %i\t%i %i\n'%(math.ceil(obs.xMin() * self.scaleFactor),math.ceil(obs.yMin() * self.scaleFactor),math.floor(obs.getDX() * self.scaleFactor),math.floor(obs.getDY() * self.scaleFactor))))
        #          #listStrBlockShapes.append(str('  Shape_%s'%i+' %0.4f %0.4f\t%0.4f %0.4f\n'%(obs.xMin()* self.scaleFactor,obs.yMin()* self.scaleFactor,obs.getDX()* self.scaleFactor,obs.getDY()* self.scaleFactor)))
        #          #listBlockShapes.append(str('%i %i\t%i %i\n'%(math.ceil(obs.xMin() * self.scaleFactor),math.ceil(obs.yMin() * self.scaleFactor),math.floor(obs.getDX() * self.scaleFactor),math.floor(obs.getDY() * self.scaleFactor))))
        #          listBlockShapes.append(str('%i %i\t%i %i\n'%((obs.xMin() * self.scaleFactor),(obs.yMin() * self.scaleFactor),(obs.getDX() * self.scaleFactor),(obs.getDY() * self.scaleFactor))))
        #
        #      listBlockShapes = list(set(listBlockShapes))
        #      for i, strBlockShape in enumerate(listBlockShapes):
        #        listStrBlockShapes.append(str('  Shape_%s'%i+' %s'%strBlockShape))
        #      nestedListBlockShapes.append(listStrBlockShapes)

        #    #f.write('%s  :  %s\n'%(blockName,len(instObstructions))
        #f.write('NumNonRectangularNodes  :  %s\n\n'%cntNonRectNodes)
        # for curListBlockShapes in nestedListBlockShapes:
        #  f.write('%s  :  %s\n'%(curListBlockShapes[0], len(curListBlockShapes)-1))
        #  for idxStrShape in range(1,len(curListBlockShapes)):
        #    f.write('%s'%curListBlockShapes[idxStrShape])
        ####################

        f.close()

    def WriteBookshelf(self, bsName):
        odb.write_def(self.block, '%s_origin.def' % (bsName))
        if not os.path.exists('output'):
            os.makedirs('output')
        if not os.path.exists('output/%s' % bsName):
            os.makedirs('output/%s' % bsName)
        self.WriteAux(bsName)
        self.WriteScl(bsName)
        self.WriteNodes(bsName)
        self.WriteRoute(bsName)
        self.WriteWts(bsName)
        self.WriteNets(bsName)
        self.WritePl(bsName)
        self.WriteShapes(bsName)
        print('Writing done')

        # debug
        self.show(bsName)

        # convert for mapping
        # self.convert(bsName)

    def convert(self, bsName):
        os.chdir('output/%s' % bsName)
        # namemap.main('%s.aux' % bsName)
        os.chdir('../../')

    def show(self, bsName):
        # print(self.chip)
        # print(self.block)
        # print(self.nets)
        # print(self.tech)
        print(self.numInsts)
        print(self.numBTerms)
        print(self.numNodes)


if __name__ == "__main__":

    ################ Settings #################
    odbPath = './odbFiles/'

    # The number of sites for cell padding (+left, +right)
    cellPaddings = [0, 1, 2, 3, 4]
    modeFormats = ['ISPD04', 'ISPD11']

    odbList = [
        'sky130hd_ISPD2006_adaptec1',
    ]

    # Layer capacity adjustment tcl file for global routing
    #layerCapacity = 'layeradjust_sky130hd.tcl'
    layerCapacity = 'layeradjust_empty.tcl'

    ###########################################

    for modeFormat in modeFormats:
        for cellPadding in cellPaddings:
            for odbName in odbList:
                db = odb.dbDatabase.create()
                print(odb)
                odb.read_db(db, '%s/%s.odb' % (odbPath, odbName))
                bs = OdbToBookshelf(
                    opendbpy=odb,
                    opendb=db,
                    cellPadding=cellPadding,
                    modeFormat=modeFormat,
                    layerCapacity=layerCapacity)
                bs.WriteBookshelf(
                    '%s_pad%s_%s' %
                    (odbName, cellPadding, modeFormat))
