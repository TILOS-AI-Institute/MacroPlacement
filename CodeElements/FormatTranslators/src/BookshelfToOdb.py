import odb
from enum import Enum
import random
import math
import copy

def ErrorQuit(msg):
  print("ERROR: %s" %(msg))
  exit(1)

# bookshelf object type
class BsType (Enum):
  MOVABLE_STD_INST = 0
  MOVABLE_MACRO_INST = 1
  FIXED_INST = 2
  PRIMARY = 3


class Instance:
  def __init__(self, name, lx, ly, width, height, isFixed):
    self.name = name
    self.lx = lx
    self.ly = ly
    self.width = width
    self.height = height

    self.isFixed = isFixed

    self.numOutputs = 0
    self.numInputs = 0
    self.isFeasible = True

    # only used for FIXED insts to generate fake macro lef.
    # have (offsetX,offsetY,direction) pairs on each pin
    self.pins = []

    # saves dbITerm objects
    self.odbIPins = []
    self.odbOPins = []

    self.odbIPinIdx = 0
    self.odbOPinIdx = 0

    # only used for FIXED insts to generate fake macro lef.
    # have (lx, ly, ux, uy) pairs on each obs.
    self.obses = []

    # saves odbInst pointer
    self.odbInst = None

    # odbMaster will be used only for "FixedInsts"
    self.odbMaster = None

    # odbClkPin will be used to create clk net
    self.odbClkPin = None

  def SetLxLy(self, lx, ly):
    self.lx = lx
    self.ly = ly

  def GetUxUy(self):
    return self.lx + self.width, self.ly + self.height

  # for nets traversing
  def IncrOutPin(self):
    self.numOutputs += 1

  def IncrInPin(self):
    self.numInputs += 1

  def NumInputs(self):
    return self.numInputs

  def NumOutputs(self):
    return self.numOutputs

  def HasObs(self):
    return len(self.obses) != 0

  # takes x, y from *.shapes -- coordinates (placedX, placedY) will be given
  def AddObs(self, shapeX, shapeY, width, height):
    placeX = shapeX - self.lx
    placeY = shapeY - self.ly
    self.obses.append([placeX, placeY, placeX + width, placeY + height])

  # takes x, y from *.nets -- all offsets are based on cell center!
  def AddPin(self, netX, netY,direction):
    self.pins.append([netX + self.width/2.0, netY + self.height/2.0, direction])

  # add Odb ITerm input pins
  def AddOdbIPin(self, odbIPin):
    self.odbIPins.append(odbIPin)

  # add Odb ITerm ouput pins
  def AddOdbOPin(self, odbOPin):
    self.odbOPins.append(odbOPin)

  # set Odb ITerm clk pins for FF
  def SetClkPin(self, odbClkPin):
    self.odbClkPin = odbClkPin

  # hashmap should be based on oPins/iPins
  def GetHashName(self):
    # return 10000 * self.width + 100* self.numOutputs + self.numInputs
    return 10000 * self.numInputs + self.width

  def IsFeasible(self):
    # there are weird cells in bookshelf
    # 1. numInputs = 0
    # 2. numOutputs = 0
    # 3. numOutputs = 2
    # following will ignore these cases

    # note that cases 1 and 2 will cause
    # "huge insts removal" at commercial pnr flow
    return self.isFeasible and self.numInputs != 0 and self.numOutputs == 1

  def SetIsFeasible(self, val):
    self.isFeasible = val

  # Previous A2A author set FF on the following types:
  def IsFF(self, minFFWidth = 20):
    return self.numInputs == 1 and self.numOutputs == 1 and self.width >= minFFWidth

  # update odbInst pointer
  def SetOdbInst(self, odbInst, ffClkPinList = None):
    self.odbInst = odbInst
    dbITerms = self.odbInst.getITerms()
    for dbITerm in dbITerms:
      if ffClkPinList != None:
        if dbITerm.getMTerm().getName() in ffClkPinList:
          self.SetClkPin(dbITerm)
      else:
        if dbITerm.getSigType() == "CLOCK":
          self.SetClkPin(dbITerm)

      if dbITerm.getSigType() == "SIGNAL":
        if dbITerm.getIoType() == "OUTPUT":
          self.AddOdbOPin(dbITerm)
        elif dbITerm.getIoType() == "INPUT":
          self.AddOdbIPin(dbITerm)

  #update odbMaster pointer for fixed insts
  def SetOdbMaster(self, odbMaster):
    self.odbMaster = odbMaster

  # used when mapping
  def RetrieveOdbInPin(self):
    if len(self.odbIPins) <= self.odbIPinIdx:
      print("WRONG(In):", self.name, self.odbIPins, self.odbIPinIdx)
    retPin = self.odbIPins[self.odbIPinIdx]
    self.odbIPinIdx += 1
    return retPin

  def RetrieveOdbOutPin(self):
    if self.odbOPinIdx >= len(self.odbOPins):
      print("WRONG(Out):", self.name, self.odbOPinIdx, self.odbOPins)
    retPin = self.odbOPins[self.odbOPinIdx]
    self.odbOPinIdx += 1
    return retPin

class Primary:
  def __init__(self, name, x, y, pinDir):
    self.name = name
    self.x = x
    self.y = y
    self.pinDir = pinDir
    self.odbBTerm = None

  def SetDir(self, pinDir):
    self.pinDir = pinDir

  def SetXY(self, x, y):
    self.x = x
    self.y = y

  def SetOdbBTerm(self, odbBTerm):
    self.odbBTerm = odbBTerm


class BookshelfToOdb:
  def __init__(self, opendbpy, opendb, file_dir,  auxName, siteName,
      macroInstPinLayer = None,
      macroInstObsLayer = None,
      primaryLayer = None,
      mastersFileName = None,
      ffClkPinList = None,
      clkNetName = "clk",
      # minFFWidth = 20,
      targetFFRatio = 0.12,
      customFPRatio = 1.0):

    self.odbpy = opendbpy
    self.odb = opendb
    self.file_dir = file_dir
    self.auxName = file_dir + '/' + auxName
    self.designName = auxName.split(".")[0]
    self.siteName = siteName
    self.ffClkPinList = ffClkPinList
    self.clkNetName = clkNetName
    # self.minFFWidth = minFFWidth
    self.targetFFRatio = targetFFRatio
    self.customFPRatio = customFPRatio

    # *.shape determine
    self.bsShapeList = []

    # 1. parse bookshelf
    self.ParseAux()

    # 2. init the odb object.
    self.InitOdb(
        macroInstPinLayer,
        macroInstObsLayer,
        primaryLayer)

    self.PostProcessInBookshelf()

    # 3. parse odb object
    self.ParseMasterUseList(mastersFileName)

    # 4. map bookshelf and odb
    self.ClassifyInsts()

    # 5. finally Fill in OpenDB
    self.FillOdb()

  def ParseAux(self):
    f = open(self.auxName, 'r')
    cont = f.read()
    f.close()

    print("Parsing %s ..." % (self.auxName) )

    nodeName = ""
    netName = ""
    shapeName = ""
    sclName = ""
    plName = ""
    routeName = ""

    for curLine in cont.split("\n"):
      # should skip 1st, 2nd elements
      for curFile in curLine.strip().split()[2:]:
        if curFile.endswith("nodes"):
          nodeName = self.file_dir + '/' + curFile
        elif curFile.endswith("nets"):
          netName = self.file_dir + '/'  + curFile
        elif curFile.endswith("shapes"):
          shapeName = self.file_dir + '/' + curFile
        elif curFile.endswith("scl"):
          sclName = self.file_dir + '/' + curFile
        elif curFile.endswith("pl"):
          plName = self.file_dir  + '/' + curFile
        elif curFile.endswith("route"):
          routeName = self.file_dir + '/' + curFile
        elif curFile.endswith("wts"):
          print("[WARNING] *.wts will be ignored")

    if nodeName == "":
      ErrorQuit("*.nodes is missing")
    if netName == "":
      ErrorQuit("*.nets is missing")
    if sclName == "":
      ErrorQuit("*.scl is missing")
    if plName == "":
      ErrorQuit("*.pl is missing")

    self.ParseNodes(nodeName)
    self.ParsePl(plName)
    self.ParseNets(netName)

    self.ParseScl(sclName)

    # The *.shape is optional!
    if shapeName != "":
      self.ParseShapes(shapeName)

    if routeName != "":
      self.ParseRoutes(routeName)

    print("Bookshelf Parsing Done")

  def ParseNodes(self, nodeName):
    print("Parsing %s ..." % (nodeName) )
    f = open(nodeName, 'r')
    cont = f.read()
    f.close()

    self.bsInstList = []
    for curLine in cont.split("\n"):
      curLine = curLine.strip()
      if curLine.startswith("UCLA") or curLine.startswith("#") \
          or curLine == "":
        continue

      if curLine.startswith("NumNodes"):
        numNodes = int(curLine.split(" ")[-1])
      elif curLine.startswith("NumTerminals"):
        numTerminals = int(curLine.split(" ")[-1])
      else:
        self.bsInstList.append(curLine.split())

    print("From Nodes: NumTotalNodes: %d" % (numNodes))
    print("From Nodes: NumTerminals: %d" % (numTerminals))

    numInsts = 0
    numFixedInsts = 0
    numPrimary = 0

    for curInst in self.bsInstList:
      if len(curInst) == 3:
        numInsts += 1
      elif curInst[-1] == "terminal":
        numFixedInsts += 1
      elif curInst[-1] == "terminal_NI":
        numPrimary += 1

    print("Parsed Nodes: NumInsts: %d" % (numInsts))
    print("Parsed Nodes: NumFixedInsts: %d" % (numFixedInsts))
    print("Parsed Nodes: NumPrimary: %d" % (numPrimary))
    print("")

  def ParseNets(self, netName):
    print("Parsing %s ..." % (netName) )
    f = open(netName, 'r')
    cont = f.read()
    f.close()

    tmpNetlist = []
    for curLine in cont.split("\n"):
      curLine = curLine.strip()
      if curLine.startswith("UCLA") or curLine.startswith("#") \
          or curLine == "":
        continue

      if curLine.startswith("NumNets"):
        numNets = int(curLine.split(" ")[-1])
      elif curLine.startswith("NumPins"):
        numPins = int(curLine.split(" ")[-1])
      else:
        tmpNetlist.append(curLine.split())

    print("From Nets: NumNets: %d" % (numNets))
    print("From Nets: NumPins: %d" % (numPins))

    self.bsNetList = []
    for idx, curArr in enumerate(tmpNetlist):
      if curArr[0] == "NetDegree":
        numPinsInNet = int(curArr[2])
        netName = curArr[3]
        pinArr = [l for l in tmpNetlist[(idx+1):(idx+numPinsInNet+1)]]
        self.bsNetList.append([netName, pinArr])

    print("Parsed Nets: NumNets: %d" %(len(self.bsNetList)))
    print("")

  def ParseShapes(self, shapeName):
    print("Parsing %s ..." % (shapeName) )
    f = open(shapeName, 'r')
    cont = f.read()
    f.close()

    tmpShapeList = []
    for curLine in cont.split("\n"):
      curLine = curLine.strip()
      if curLine.startswith("UCLA") or curLine.startswith("#") \
          or curLine == "":
        continue

      if curLine.startswith("NumNonRectangularNodes"):
        numNonRectNodes = int(curLine.split(" ")[-1])
      else:
        tmpShapeList.append(curLine.split())
    print("From Shapes: NumRectLinearInsts: %d" % (numNonRectNodes))

    self.bsShapeList = []
    for idx, curArr in enumerate(tmpShapeList):
      # find 'InstName : numShapes' string
      if curArr[1] == ":":
        instName = curArr[0]
        numShapesInInst = int(curArr[2])
        shapeArr = tmpShapeList[(idx+1):(idx+numShapesInInst+1)]
        self.bsShapeList.append([instName,shapeArr])
    print("Parsed Shapes: NumRectLinearInsts: %d" %(len(self.bsShapeList)))
    print("")


  def ParseScl(self, sclName):
    print("Parsing %s ..." % (sclName) )
    f = open(sclName, 'r')
    cont = f.read()
    f.close()

    tmpRowList = []
    for curLine in cont.split("\n"):
      curLine = curLine.strip()
      if curLine.startswith("UCLA") or curLine.startswith("#") \
          or curLine == "":
        continue

      if curLine.startswith("NumRows") or curLine.startswith("Numrows"):
        numRows = int(curLine.split(" ")[-1])
      else:
        tmpRowList.append(curLine.split())
    print("From scl: NumRows: %d" % (numRows))

    # extract indices on CoreRow/End
    coreRowIdxList = [idx for idx,tmpArr in enumerate(tmpRowList) if tmpArr[0] == "CoreRow"]
    endIdxList = [idx for idx,tmpArr in enumerate(tmpRowList) if tmpArr[0] == "End"]

    if len(coreRowIdxList) != len(endIdxList):
      ErrorQuit("The number of CoreRow and End is different in scl!")

    self.bsRowList = []
    for idx1, idx2 in zip(coreRowIdxList, endIdxList):
      self.bsRowList.append(tmpRowList[idx1:idx2])
    print("Parsed scl: NumRows: %d" %(len(self.bsRowList)))
    print("")

  def ParsePl(self, plName):
    print("Parsing %s ..." % (plName) )
    f = open(plName, 'r')
    cont = f.read()
    f.close()

    self.bsPlList = []
    for curLine in cont.split("\n"):
      curLine = curLine.strip()
      if curLine.startswith("UCLA") or curLine.startswith("#") \
          or curLine == "":
        continue

      self.bsPlList.append(curLine.split())
    print("Parsed pl: NumInstsInPl: %d" % (len(self.bsPlList)))

    numFixedInsts = [0 for curArr in self.bsPlList if curArr[-1] == "/FIXED"]
    numPrimary = [0 for curArr in self.bsPlList if curArr[-1] == "/FIXED_NI"]

    print("Parsed pl: NumFixedInsts: %d" % (len(numFixedInsts)))
    print("Parsed pl: NumPrimary: %d" % (len(numPrimary)))
    print("")

  def ParseRoutes(self, routeName):
    pass

  def IsFeasibleMaster(self, odbMaster):
    numOutputs = 0
    numInputs = 0

    for mTerm in odbMaster.getMTerms():
      if mTerm.getSigType() == "SIGNAL":
        # skip for FF clk pin
        if self.ffClkPinList != None:
          if mTerm.getConstName() in self.ffClkPinList:
            continue

        if mTerm.getIoType() == "OUTPUT":
          numOutputs += 1
        elif mTerm.getIoType() == "INPUT":
          numInputs += 1

    # limit the cells as numOutputs == 1
    # In particular, allow 2-pin outputs on FFs. (e.g., Q/QN pin cases)
    if odbMaster.isSequential():
      isFeasible = (numOutputs in [1,2] and numInputs != 0)
    else:
      isFeasible = (numOutputs == 1 and numInputs != 0)

    if isFeasible == False:
      print("[WARNING] %s has I/O = %d/%d, so skipped" % \
          (odbMaster.getName(), numInputs, numOutputs))

    return isFeasible


  def ParseMasterUseList(self, mastersFileName):
    # parse master lists if exists

    self.masters = []
    if mastersFileName != None:
      f = open(mastersFileName, 'r')
      cont = f.read()
      f.close()

      for curLine in cont.split("\n"):
        curLine = curLine.strip()
        if curLine == "":
          continue

        odbMaster = self.odb.findMaster(curLine)
        if odbMaster == None:
          print("[WARNING] cannot find master (%s) in OpenDB" % (curLine))
        elif self.IsFeasibleMaster(odbMaster):
          self.masters.append(odbMaster)

      print("Parsed master use list: Total %d masters" % (len(self.masters)))

    # extract cell lists from odb
    if len(self.masters) == 0:

      libs = self.odb.getLibs()
      for lib in libs:
        masters = lib.getMasters()
        for master in masters:
          if self.IsFeasibleMaster(master):
            self.masters.append(master)

      if len(self.masters) == 0:
        ErrorQuit("Cannot find available master cells in OpenDB")

      print("Use all masters available in OpenDB: %d masters" % (len(self.masters)))

    ffArr = [0 for m in self.masters if m.isSequential()]

    if len(ffArr) == 0:
      ErrorQuit("Cannot find sequential cells in OpenDB")

    print("NumSequentialCells: %d" %(len(ffArr)))

    # retrive site info from ODB
    print("GivenSite: %s" % (self.siteName))
    libs = self.odb.getLibs()

    for lib in libs:
      curSite = lib.findSite(self.siteName)
      if curSite != None:
        break

    if curSite == None:
      ErrorQuit("Cannot find site %s from OpenDB" %(self.siteName))

    self.odbSite = curSite
    self.odbSiteWidth = int(curSite.getWidth())
    self.odbSiteHeight = int(curSite.getHeight())
    self.bsDbuRatio = 1.0 * int(self.odbSiteHeight) / int(self.rowHeight) * self.customFPRatio
    print("siteWidth: %d, siteHeight: %d" % (self.odbSiteWidth, self.odbSiteHeight))
    print("BookshelfDbuRatio: %.2f" % (self.bsDbuRatio) )
    print("")

    # Note that
    # we should match the cells that has smaller errors
    # on the following two values
    #
    # 1) (bookshelf) cell width
    # 2) (lef) cell width / self.bsDbuRatio

    # key: numInputs
    # val: list of [bsWidth, masters]
    # -- bsWidth is required as key to sort cells quickly.
    #
    # note that #output == 1.

    self.masterInstMap = {}
    self.masterFFMap = {}

    for master in self.masters:
      numInPins = 0
      numOutPins = 0

      for mTerm in master.getMTerms():
        # only for SIGNAL pins
        if mTerm.getSigType() != "SIGNAL":
          continue

        # skip for clock pin list
        if self.ffClkPinList != None and mTerm.getConstName() in self.ffClkPinList:
          continue

        if mTerm.getIoType() == "INPUT":
          numInPins += 1
        elif mTerm.getIoType() == "OUTPUT":
          numOutPins += 1

      bsWidth = int( math.floor(master.getWidth() /self.bsDbuRatio))

      # ff inst master --> update masterFFMap
      if master.isSequential():
        if numInPins in self.masterFFMap:
          self.masterFFMap[numInPins].append([bsWidth, master])
        else:
          self.masterFFMap[numInPins] = [[bsWidth, master]]

      # normal inst master --> update masterInstMap
      else:
        if numInPins in self.masterInstMap:
          self.masterInstMap[numInPins].append([bsWidth, master])
        else:
          self.masterInstMap[numInPins] = [[bsWidth,master]]

    # sort val(bsWidth-master list) by bsWidth as increasing order.
    # for masterInstMap
    for key, val in self.masterInstMap.items():
      self.masterInstMap[key] = sorted(val, key=lambda x: (x[0]))

    # for masterFFMap
    for key, val in self.masterFFMap.items():
      self.masterFFMap[key] = sorted(val, key=lambda x: (x[0]))

    print("Available inst master info from OpenDB")
    for key, val in self.masterInstMap.items():
      print("numInputs:", key, "minWidth:", val[0][0],
          "maxWidth:", val[-1][0], "masterCnt", len(val))

    print("")

    print("Available ff master info from OpenDB")
    for key, val in self.masterFFMap.items():
      print("numInputs:", key, "minWidth:", val[0][0],
          "maxWidth:", val[-1][0], "masterCnt", len(val))
    print("")

  # on newblue, some inst has multi-height cells
  def IsMacro(self, bsInstHeight):
    return (bsInstHeight > self.rowHeight * 3)

  def PostProcessInBookshelf(self):
    print("Start Bookshelf post processing ...")
    self.movableStdInsts = []
    self.movableMacroInsts = []
    self.fixedInsts = []
    self.primary = []

    # Name to idx hash map
    self.movableStdInstDict = {}
    self.movableMacroInstDict = {}
    self.fixedInstDict = {}
    self.primaryDict = {}

    # Name to bsType Map
    # See details on class BsType
    self.typeDict = {}

    # extract first row height from bsRowList
    self.rowHeight = int(self.bsRowList[0][2][2])
    print("SclRowHeight:", self.rowHeight)

    for curInst in self.bsInstList:
      if len(curInst) == 3:
        # normal STD cell
        if self.IsMacro(int(curInst[2])) == False:
          self.movableStdInstDict[curInst[0]] = len(self.movableStdInsts)
          self.movableStdInsts.append(
              Instance(name = curInst[0],
                        lx = 0,
                        ly = 0,
                        width = int(curInst[1]),
                        height = self.rowHeight,
                        isFixed = False))
          self.typeDict[curInst[0]] = BsType.MOVABLE_STD_INST
        # movable macro cell
        else:
          self.movableMacroInstDict[curInst[0]] = len(self.movableMacroInsts)
          self.movableMacroInsts.append(
              Instance(name = curInst[0],
                lx = 0,
                ly = 0,
                width = int(curInst[1]),
                height = int(curInst[2]),
                isFixed = False))

          self.typeDict[curInst[0]] = BsType.MOVABLE_MACRO_INST

      elif len(curInst) == 4:
        # fixed primary (input/output)
        # on old bookshelf, terminal with size=(0,0) or (1,1) is primary.
        if curInst[3] == "terminal_NI" or \
            (curInst[3] == "terminal" and int(curInst[1]) <= 1 and int(curInst[2]) <=1):
          self.primaryDict[curInst[0]] = len(self.primary)
          self.primary.append(
              Primary(name = curInst[0],
                x = 0,
                y = 0,
                pinDir = "NONE"))
          self.typeDict[curInst[0]] = BsType.PRIMARY
        # fixed insts (either std/macro)
        elif curInst[3] == "terminal":
          self.fixedInstDict[curInst[0]] = len(self.fixedInsts)
          self.fixedInsts.append(
              Instance(name = curInst[0],
                lx = 0,
                ly = 0,
                width = int(curInst[1]),
                height = int(curInst[2]),
                isFixed = True))
          self.typeDict[curInst[0]] = BsType.FIXED_INST

    # traverse bsNetList to update instances
    for curNet in self.bsNetList:
      for curPin in curNet[1]:
        objName = curPin[0]
        objDir = curPin[1]
        bsType = self.typeDict[objName]
        if bsType == BsType.MOVABLE_STD_INST:
          idx = self.movableStdInstDict[objName]
          # update pin cnt
          # no need to handle offsets
          if objDir == "O":
            self.movableStdInsts[idx].IncrOutPin()
          elif objDir == "I":
            self.movableStdInsts[idx].IncrInPin()

        # Movable Macro cases
        elif bsType == BsType.MOVABLE_MACRO_INST:
          idx = self.movableMacroInstDict[objName]

          # update pin cnt
          if objDir == "O":
            self.movableMacroInsts[idx].IncrOutPin()
          elif objDir == "I":
            self.movableMacroInsts[idx].IncrInPin()

          # update pin locs
          if len(curPin) >= 5:
            coordiX = float(curPin[3])
            coordiY = float(curPin[4])
          else:
            coordiX = coordiY = 0
          self.movableMacroInsts[idx].AddPin(coordiX,coordiY,objDir)

        # Fixed Macro cases
        elif bsType == BsType.FIXED_INST:
          idx = self.fixedInstDict[objName]

          if objDir == "O":
            self.fixedInsts[idx].IncrOutPin()
          elif objDir == "I":
            self.fixedInsts[idx].IncrInPin()

          # update pin locs
          if len(curPin) >= 5:
            coordiX = float(curPin[3])
            coordiY = float(curPin[4])
          else:
            coordiX = coordiY = 0
          self.fixedInsts[idx].AddPin(coordiX,coordiY,objDir)

        # primary cases
        elif bsType == BsType.PRIMARY:
          idx = self.primaryDict[objName]
          self.primary[idx].SetDir(objDir)

    # traverse bsPl to update fixed locations
    for curPl in self.bsPlList:
      plObjName = curPl[0]

      # FixedInsts
      if curPl[-1] == "/FIXED":
        idx = self.fixedInstDict[plObjName]
        self.fixedInsts[idx].SetLxLy(
            float(curPl[1]),
            float(curPl[2]))

      # Primary
      elif curPl[-1] == "/FIXED_NI":
        idx = self.primaryDict[plObjName]
        self.primary[idx].SetXY(
            float(curPl[1]),
            float(curPl[2]))

    # traverse bsShapeList to fill in obs structure of fixedInsts
    for curInst in self.bsShapeList:
      instName = curInst[0]
      idx = self.fixedInstDict[instName]
      # add obs on fixedInsts
      for curShape in curInst[1]:
        self.fixedInsts[idx].AddObs(
            int(curShape[1]),
            int(curShape[2]),
            int(curShape[3]),
            int(curShape[4]))

    print("NumMovableStdInsts:", len(self.movableStdInsts))
    print("NumMovableMacroInsts:", len(self.movableMacroInsts))
    print("NumFixedInsts:", len(self.fixedInsts))
    print("NumPrimary:", len(self.primary))
    print("Post processing of Bookshelf is done")

  # determine FF minFFWidth
  def DetermineFFCondition(self, targetFFRatio = 0.12):
    # sort inst (numInputs == 1) by
    candidateInsts = [l for l in self.allStdInsts \
        if l.numInputs == 1 and l.numOutputs == 1]

    candidateInstMap = {}
    for inst in candidateInsts:
      if inst.width in candidateInstMap:
        candidateInstMap[inst.width].append(inst)
      else:
        candidateInstMap[inst.width] = [inst]

    tmpKeys = list(candidateInstMap.keys())
    tmpVals = list(candidateInstMap.values())
    candidateInstList = [(key,val) for key,val in zip(tmpKeys,tmpVals)]
    candidateInstList.sort( reverse=True )

    accmInsts = 0
    prevMinFFWidth = 0
    prevRatio = 0
    for instPair in candidateInstList:
      accmInsts += len(instPair[1])
      # exceeds the given ratio!
      ratio = float(accmInsts) / len(self.allStdInsts)

      if ratio >= targetFFRatio:
        # if there is cutting point where 0.09~0.12 exists, choose it
        if prevRatio >= 0.09:
          self.minFFWidth = prevMinFFWidth
        # if the cutting point < 0.09, takes > 0.12 point
        else:
          self.minFFWidth = instPair[0]
        break

      prevMinFFWidth = instPair[0]
      prevRatio = ratio

    # if #FF cells didn't reach the target FF ratio --> use all FF cell
    if float(accmInsts) / len(self.allStdInsts) < targetFFRatio:
      self.minFFWidth = 0

    print("minFFCellWidth: %d" %(self.minFFWidth))
    print("")


  def ClassifyInsts(self):
    self.pinNonFFInstDict = {}
    self.pinFFInstDict = {}

    self.numSkipInsts = 0
    self.numFFInsts = 0

    allFixedStdInsts = [l for l in self.fixedInsts if self.IsMacro(l.height) == False]

    self.allStdInsts = self.movableStdInsts + allFixedStdInsts

		# retrive minFFWidth
    self.DetermineFFCondition(self.targetFFRatio)

    for curInst in self.allStdInsts:
      # skip for weird cells in academic benchmark
      if curInst.IsFeasible() == False:
        self.numSkipInsts += 1
        continue

      # skip for inst that are not available in masterUseList
      if curInst.IsFF(self.minFFWidth):
        if not curInst.numInputs in self.masterFFMap:
          self.numSkipInsts += 1
          curInst.SetIsFeasible(False)
          continue
      else:
        if not curInst.numInputs in self.masterInstMap:
          self.numSkipInsts += 1
          curInst.SetIsFeasible(False)
          continue

      # only outPin = 1 and inPin > 0 survived now.
      hashKey = curInst.GetHashName()

      # update FF map
      if curInst.IsFF(self.minFFWidth):
        self.numFFInsts += 1
        if hashKey in self.pinFFInstDict:
          self.pinFFInstDict[hashKey].append(curInst)
        else:
          self.pinFFInstDict[hashKey] = [curInst]
      # update nonFF map
      else:
        if hashKey in self.pinNonFFInstDict:
          self.pinNonFFInstDict[hashKey].append(curInst)
        else:
          self.pinNonFFInstDict[hashKey] = [curInst]


    print("NumSkippedInsts: %d (%.2f percent)"
        % ( self.numSkipInsts,
          1.0 * self.numSkipInsts / len(self.allStdInsts) * 100 ))
    print("NumAssignedFFs: %d (%.2f percent)"
        % ( self.numFFInsts,
          1.0 * self.numFFInsts / (len(self.allStdInsts) - self.numSkipInsts) * 100) )

    # convert 2d dict into 2d list to sort
    tmpKeys = list(self.pinNonFFInstDict.keys())
    tmpVals = list(self.pinNonFFInstDict.values())
    self.pinNonFFInstList = [(key,val) for key,val in zip(tmpKeys,tmpVals)]

    tmpKeys = list(self.pinFFInstDict.keys())
    tmpVals = list(self.pinFFInstDict.values())
    self.pinFFInstList = [(key,val) for key,val in zip(tmpKeys,tmpVals)]

    # sort
    self.pinNonFFInstList.sort()
    self.pinFFInstList.sort()

    print("NonFF Cell info from Bookshelf. Key = 10000 * numInputs + width)")
    for key, val in self.pinNonFFInstList:
      print("key", key, "numInst:", len(val))

    print("FF Cell info from Bookshelf. Key = 10000 * numInputs + width)")
    for key, val in self.pinFFInstList:
      print("key", key, "numInst:", len(val))

  # mode = 0: NonFFInst
  # mode = 1: FFInst
  def GetMasterMapList(self, key, numInsts, mode):
    numInputs = key // 10000
    width = key % 10000

    if mode == 0:
      masters = self.masterInstMap[numInputs][:]
    else:
      masters = self.masterFFMap[numInputs][:]

    #print("retrieved masters")
    #for l in masters:
    #  print(l[0], l[1].getName())


    # first - diff on cellWidth
    # second - odb master
    masters = [ [abs(width-l[0]),l[1]] for l in masters ]

    # get min on cellWidthDiff
    minX = min([ l[0] for l in masters ])

    # extract all masters that has minX
    masters = [ l[1] for l in masters if l[0] == minX ]

    #print("Mode: %s " % ("FF" if mode == 0 else "INST"),
    #    "key:", key,
    #    "min(widthDiff):", minX,
    #    "bsWidth:", width,
    #    "masters:", ",".join([l.getName() for l in masters]))

    # quotient
    numInstsPerMacro = numInsts // len(masters)
    retArr = [l for l in masters for j in range(0,numInstsPerMacro)]

    # remainder problem.
    while len(retArr) < numInsts:
      retArr.append(masters[0])

    # shuffle the master mapping
    random.seed(0)
    random.shuffle(retArr)

    return retArr

  def GetNonFFMasterMapList(self, key, numInsts):
    return self.GetMasterMapList(key, numInsts, mode = 0)

  def GetFFMasterMapList(self, key, numInsts):
    return self.GetMasterMapList(key, numInsts, mode = 1)

  # init chip and block obj
  def InitOdb(self,
      macroInstPinLayer,
      macroInstObsLayer,
      primaryLayer):

    # initialize dbChip
    chip = self.odb.getChip()
    if chip != None:
      print("[WARNING] Chip obj is already initialized")
    else:
      chip = self.odbpy.dbChip_create(self.odb)

    # initialize dbBlock
    block = chip.getBlock()
    if block != None:
      print("[WARNING] Block obj is already initialized")
    else:
      block = self.odbpy.dbBlock_create(chip, self.designName)

    self.odbBlock = block

    # default dbu is from LEF
    odbTech = self.odb.getTech()
    self.dbu = originalLEFDbu = odbTech.getDbUnitsPerMicron()

    odbTech.setDbUnitsPerMicron(originalLEFDbu)
    self.odbBlock.setDefUnits(self.dbu)
    self.manufacturingGrid = int(odbTech.getManufacturingGrid())
    print("[INFO] ManuFacturingGrid:", self.manufacturingGrid)

    # retrieve layer info
    # 1. fixed macro insts pin layer
    # default: metal 3, 4
    if macroInstPinLayer == None:
      odbMacroInstPinLayer = [odbTech.findRoutingLayer(l) for l in range(3,5)]
      horLayer = [l for l in odbMacroInstPinLayer if l.getDirection() == "HORIZONTAL"]
      verLayer = [l for l in odbMacroInstPinLayer if l.getDirection() == "VERTICAL"]

      if len(horLayer) != 1 or len(verLayer) != 1:
        print("[ERROR] Cannot find proper layers for macro inst pin layers.\n"
            + "        Please put two routing layers for macro inst pin layers")
        exit(1)

      self.macroInstPinHorLayer = horLayer[0]
      self.macroInstPinVerLayer = verLayer[0]
      self.macroInstPinLowerLayer = odbMacroInstPinLayer[0]

      print("[WARNING] Fixed macro insts' pin layer is assigned as H: "
          + self.macroInstPinHorLayer.getName()
          + " V: " + self.macroInstPinVerLayer.getName())

    elif len(macroInstPinLayer) != 2:
      print("[ERROR] Received " + str(len(macroInstPinLayer)) + " layers.\n"
          + "        Please put two routing layers for macro inst pin layers" )
      exit(1)
    else:
      odbMacroInstPinLayer = [odbTech.findLayer(l) for l in macroInstPinLayer]
      horLayer = [l for l in odbMacroInstPinLayer if l.getDirection() == "HORIZONTAL"]
      verLayer = [l for l in odbMacroInstPinLayer if l.getDirection() == "VERTICAL"]

      if len(horLayer) != 1 or len(verLayer) != 1:
        print("[ERROR] Cannot find proper layers for macro inst pin layers.\n"
            + "        Please put two routing layers for macro inst pin layers")
        exit(1)

      self.macroInstPinHorLayer = horLayer[0]
      self.macroInstPinVerLayer = verLayer[0]
      self.macroInstPinLowerLayer = odbMacroInstPinLayer[0]

      print("[INFO] Fixed macro insts' pin layer is assigned as H: "
          + self.macroInstPinHorLayer.getName()
          + " V: " + self.macroInstPinVerLayer.getName())


    # 2. fixed macro insts obs layer -- m1-m4 v1-v3
    if macroInstObsLayer == None:
      self.macroInstObsLayer = [odbTech.findLayer(l) for l in range(1,6)]
      print("[WARNING] Fixed macro insts' pin layer is assigned as \n" +
          "\n".join([m.getName() for m in self.macroInstObsLayer]) + "\n")
    else:
      self.macroInstObsLayer = [odbTech.findLayer(l) for l in macroInstObsLayer]

    # 3. primary pins layer (input/output PINS in def)
    # default: metal 4
    if primaryLayer == None:
      self.primaryLayer = odbTech.findRoutingLayer(4)
      print("[WARNING] primary pin layer is assigned as " +
         self.primaryLayer.getName())
    else:
      self.primaryLayer = odbTech.findLayer(primaryLayer)

    # Create OVERLAP layer for rectilinear macro definition
    # this is only needed when *.shape is given
    if len(self.bsShapeList) != 0:
      if odbTech.findLayer("OVERLAP") == None:
        self.odbpy.dbTechLayer_create(odbTech, "OVERLAP", "OVERLAP")

      self.macroInstObsLayer.append(odbTech.findLayer("OVERLAP"))

  def FillOdb(self):
    self.FillOdbRows()
    self.FillOdbMacroLef()
    self.FillOdbStdInsts()
    self.FillOdbFixedMacroInsts()
    self.FillOdbMovableMacroInsts()
    self.FillOdbNets()
    self.FillOdbClockNet()

  # note that considering fragemented ROW is not acceptable
  # due to different site heights on different tech.
  #
  # Retrive lx, ly, ux, uy of coreArea and create
  def FillOdbRows(self):

    lx = 1e30
    ly = 1e30
    ux = -1e30
    uy = -1e30

    for curRow in self.bsRowList:
      rowLy = int(curRow[1][-1])
      rowUy = rowLy + 1
      rowLx = int(curRow[-1][2])
      rowUx = rowLx + int(curRow[-1][-1])

      lx = min(lx, rowLx)
      ly = min(ly, rowLy)
      ux = max(ux, rowUx)
      uy = max(uy, rowUy)

    print("BookshelfCore:", lx, ly, ux, uy)

    coreDbu = [lx, ly, ux, uy]
    coreDbu = [self.GetGridCoordi(int(l * self.bsDbuRatio)) for l in coreDbu]
    coreDbuStr = [str(l) for l in coreDbu]

    print("DEFCore:", " ".join(coreDbuStr))

    dbuLx = coreDbu[0]
    dbuLy = coreDbu[1]
    dbuUx = coreDbu[2]
    dbuUy = coreDbu[3]

    numSites = int(round(float(dbuUx - dbuLx)/self.odbSiteWidth))

    for idx, curLy in enumerate(range(dbuLy,
      dbuUy,
      self.odbSiteHeight)):

      self.odbpy.dbRow_create(self.odbBlock,
        "ROW_%d" % (idx),
        self.odbSite,
        dbuLx, curLy,
        "R0" if idx % 2 == 0 else "MX",
        "HORIZONTAL",
        numSites,
        self.odbSiteWidth)

      # update dbuUy
      if dbuUy < curLy + self.odbSiteHeight:
        dbuUy = curLy + self.odbSiteHeight

    print("Total %d Rows are created in OpenDB" % (len(self.odbBlock.getRows())))

    # note that die to core spacing is equal to dbuLx and dbuLy
    dieUx = dbuUx + dbuLx
    dieUy = dbuUy + dbuLy

    # due to macro placement snapping, we need to increase the die area.
    # first, calculate macro placement offset.
    pitchY = self.macroInstPinHorLayer.getPitchY()
    offsetY = self.macroInstPinHorLayer.getOffsetY()
    self.macroInstHorLayerOffset = offsetY
    #= (pitchY + offsetY - (dbuLy % pitchY)) % pitchY

    pitchX = self.macroInstPinVerLayer.getPitchX()
    offsetX = self.macroInstPinVerLayer.getOffsetX()
    self.macroInstVerLayerOffset = offsetX
    # = (pitchX + offsetX - (dbuLx % pitchX)) % pitchX

    print("Vertical(X) Layer:", self.macroInstPinVerLayer.getName())
    print("c2d", dbuLx, "pitch", self.macroInstPinVerLayer.getPitchX())
    print("offset", self.macroInstPinVerLayer.getOffsetX())

    print("Macro Place Offset - x: %d, y: %d "
        % (self.macroInstVerLayerOffset,
        self.macroInstHorLayerOffset))

    dieUx = dieUx + self.macroInstVerLayerOffset
    dieUy = dieUy + self.macroInstHorLayerOffset

    rect = self.odbpy.Rect(0, 0, dieUx, dieUy)
    self.odbBlock.setDieArea(rect)
    print("DEFDie: %d %d %d %d" % (0, 0, dieUx, dieUy))
    print("")

  def GetGridCoordi(self, coordi):
    return self.GetSnapCoordi(self.manufacturingGrid, coordi)

  def GetSiteCoordi(self, coordi):
    return self.GetSnapCoordi(self.odbSiteHeight, coordi)

  def GetSnapCoordi(self, gridUnit, coordi):
    return (coordi // gridUnit) * gridUnit


  # takes list of [x, y] and generate snapped pin locations
  def SnapFixedMacroPinLocations(self, pins, odbMaster):
    width = odbMaster.getWidth()
    height = odbMaster.getHeight()

    pitchX = self.macroInstPinVerLayer.getPitch() * 2
    pitchY = self.macroInstPinHorLayer.getPitch() * 2
    cntX = width // pitchX
    cntY = height // pitchY

    # make 2D grid
    grid = []

    # 2D grid init
    for i in range(cntX):
      tmpGrid = []
      for j in range(cntY):
        tmpGrid.append(-1)
      grid.append(tmpGrid)


    newPins = copy.deepcopy(pins)
    unplacedPins = []

    # place pins on 2D grid
    for idx, pin in enumerate(pins):
      idxX = int(self.bsDbuRatio * pin[0]) // pitchX
      idxY = int(self.bsDbuRatio * pin[1]) // pitchY
      idxX = max(0, min(cntX-1, idxX))
      idxY = max(0, min(cntY-1, idxY))

      if grid[idxX][idxY] == -1:
        grid[idxX][idxY] = idx
      else:
        unplacedPins.append(idx)

    newUnplacedPins = []
    for idx in unplacedPins:
      idxX = int(self.bsDbuRatio * pins[idx][0]) // pitchX
      idxY = int(self.bsDbuRatio * pins[idx][1]) // pitchY
      idxX = max(0, min(cntX-1, idxX))
      idxY = max(0, min(cntY-1, idxY))

      isFound = False
      for dist in range(0,100):

        # spiral
        for x in range(0, dist):
          y = dist - x

          for nx, ny in [[x,y],[x,-y],[-x,y],[-x,-y]]:
            nIdxX = max(0, min(cntX-1, idxX+nx))
            nIdxY = max(0, min(cntY-1, idxY+ny))

            if grid[nIdxX][nIdxY] == -1:
              grid[nIdxX][nIdxY] = idx
              isFound = True
              break

          if isFound:
            break

      if isFound == False:
        newUnplacedPins.append(idx)

    if len(newUnplacedPins) > 0:
      print("[ERROR] Cannot find 2D grid points on current macros.")
      exit(1)

    for idxX in range(0, cntX):
      for idxY in range(0, cntY):
        if grid[idxX][idxY] != -1:
          pIdx = grid[idxX][idxY]
          # the new pins will have ongrid location
          newPins[pIdx][0] = pitchX * idxX
          newPins[pIdx][1] = pitchY * idxY

    return newPins

  def FillOdbMacroLef(self):
    self.odbLib = self.odbpy.dbLib_create(self.odb, "fakeMacros")
    numCreatedMacros = 0

    widthSnapGrid = self.macroInstPinVerLayer.getPitchX()
    heightSnapGrid = self.macroInstPinHorLayer.getPitchY()

    # create dbMaster obj
    for macroInst in self.fixedInsts + self.movableMacroInsts:
      if self.IsMacro(macroInst.height):
        odbMaster = self.odbpy.dbMaster_create(self.odbLib,
            "fake_macro_%s_%s" % (self.designName, macroInst.name.replace("/","_")))
        odbMaster.setType("BLOCK")
        odbMaster.setOrigin(0,0)

        # macro width scaling -- aware manufacturingGrid
        odbMaster.setWidth( self.GetSnapCoordi( widthSnapGrid,
          int(self.bsDbuRatio * macroInst.width)) )

        odbMaster.setHeight( self.GetSnapCoordi( heightSnapGrid,
          int(self.bsDbuRatio * macroInst.height)) )

        odbMaster.setSymmetryX()
        odbMaster.setSymmetryY()

        # print(odbMaster.isBlock(), odbMaster.getMasterId())
        macroInst.SetOdbMaster(odbMaster)

        numCreatedMacros += 1
        if numCreatedMacros % 10000 == 0:
          print("%d macros are created in OpenDB" % (numCreatedMacros))


        newPins = self.SnapFixedMacroPinLocations(macroInst.pins, odbMaster)

        # create PIN
        pinWidth = self.macroInstPinLowerLayer.getWidth()
        for idx, curPin in enumerate(newPins):
          pinDir = "OUTPUT" if curPin[2] == 'O' else "INPUT" if curPin[2] == 'I' else "INOUT"
          odbMTerm = self.odbpy.dbMTerm_create(odbMaster, "p%d" % (idx), pinDir, "SIGNAL")
          odbMPin = self.odbpy.dbMPin_create(odbMTerm)

          # fixed macro insts case
          # create PIN
          # note that all pins are already upscaled by bsDbuRatio on snapping function
          self.odbpy.dbBox_create(odbMPin,
              self.macroInstPinLowerLayer,
              int(self.GetGridCoordi(round(curPin[0] - pinWidth/2.0))),
              int(self.GetGridCoordi(round(curPin[1] - pinWidth/2.0))),
              int(self.GetGridCoordi(round(curPin[0] + pinWidth/2.0))),
              int(self.GetGridCoordi(round(curPin[1] + pinWidth/2.0))))

        # create OBS only for Macro
        # on whole cell area if *.shape is not exist
        if len(macroInst.obses) == 0:
          for curLayer in self.macroInstObsLayer:
            self.odbpy.dbBox_create(odbMaster,
                curLayer,
                0, 0,
                int(self.GetGridCoordi(round(self.bsDbuRatio * macroInst.width))),
                int(self.GetGridCoordi(round(self.bsDbuRatio * macroInst.height))))
        # on partial rectilinear cell area if *.shape is exist
        else:
          for curLayer in self.macroInstObsLayer:
            for curObs in macroInst.obses:
              self.odbpy.dbBox_create(odbMaster,
                  curLayer,
                  int(self.GetGridCoordi(round(self.bsDbuRatio * curObs[0]))),
                  int(self.GetGridCoordi(round(self.bsDbuRatio * curObs[1]))),
                  int(self.GetGridCoordi(round(self.bsDbuRatio * curObs[2]))),
                  int(self.GetGridCoordi(round(self.bsDbuRatio * curObs[3]))))
        # set Frozen to use in the Block section
        odbMaster.setFrozen()
    print("Total %d macros are created in OpenDB" % (numCreatedMacros))

  # fill dbInst (components) on movable insts
  def FillOdbStdInsts(self):
    for key, insts in self.pinNonFFInstList:
      masterMapList = self.GetNonFFMasterMapList( key, len(insts) )

      for inst, master in zip(insts, masterMapList):
        odbInst = self.odbpy.dbInst_create(self.odbBlock, master, inst.name )
        inst.SetOdbInst(odbInst, ffClkPinList = None)

    for key, insts in self.pinFFInstList:
      masterMapList = self.GetFFMasterMapList( key, len(insts) )

      for inst,master in zip(insts, masterMapList):
        odbInst = self.odbpy.dbInst_create(self.odbBlock, master, inst.name )
        inst.SetOdbInst(odbInst, ffClkPinList = self.ffClkPinList)

  # fill dbInst (components) on Fixed insts
  def FillOdbFixedMacroInsts(self):
    widthSnapGrid = self.macroInstPinVerLayer.getPitchX()
    heightSnapGrid = self.macroInstPinHorLayer.getPitchY()

    for fixedInst in self.fixedInsts:
      # only for macros
      if self.IsMacro(fixedInst.height):
        odbInst = self.odbpy.dbInst_create(self.odbBlock,
            fixedInst.odbMaster,
            fixedInst.name)
        odbInst.setOrigin(
            self.GetSnapCoordi( widthSnapGrid,
              int(round(self.bsDbuRatio * fixedInst.lx)))
              + self.macroInstVerLayerOffset,

            self.GetSnapCoordi( heightSnapGrid,
              int(round(self.bsDbuRatio * fixedInst.ly)))
              + self.macroInstHorLayerOffset)

        odbInst.setPlacementStatus("LOCKED")
        fixedInst.SetOdbInst(odbInst, ffClkPinList = None)

  def FillOdbMovableMacroInsts(self):
    widthSnapGrid = self.macroInstPinVerLayer.getPitchX()
    heightSnapGrid = self.macroInstPinHorLayer.getPitchY()

    for macroInst in self.movableMacroInsts:
      print("Movable Macro Inst:", macroInst.name)
      # only for macros
      if self.IsMacro(macroInst.height):
        odbInst = self.odbpy.dbInst_create(self.odbBlock,
            macroInst.odbMaster,
            macroInst.name)

        odbInst.setPlacementStatus("UNPLACED")
        print("Macro SetOdbInst:", macroInst.name)
        macroInst.SetOdbInst(odbInst, ffClkPinList = None)


  # The dbBTerm (terminal_NI) instances must be initialized
  # during the net traversal because dbBTerm requires dbNet pointer.
  def FillOdbNets(self):
    netCnt = 0
    for curNet in self.bsNetList:
      netName = curNet[0]
      dbNet = self.odbpy.dbNet_create(self.odbBlock, netName)

      netCnt += 1
      if netCnt % 10000 == 0:
        print("%d nets are created in OpenDB" % (netCnt))

      for curPin in curNet[1]:
        iName = curPin[0]
        iTermDir = curPin[1]

        bsType = self.typeDict[iName]

        # primary type
        if bsType == BsType.PRIMARY:
          curPrimary = self.primary[self.primaryDict[iName]]

          # primary -> dbBTerm create
          dbBTerm = self.odbpy.dbBTerm_create(dbNet, netName)

          # bookshelf benchmark has wrong pi/po pin connections sometimes
          # if duplicated PI/POs are met, ignore.
          if dbBTerm != None:
            dbBTerm.setIoType("INPUT" if iTermDir == "I" else
                "OUTPUT" if iTermDir == "O" else "INOUT")

            dbBPin = self.odbpy.dbBPin_create(dbBTerm)

            cx = self.bsDbuRatio * curPrimary.x
            cy = self.bsDbuRatio * curPrimary.y

            mWidth = self.primaryLayer.getWidth()

            # create bbox pin shapes
            self.odbpy.dbBox_create(dbBPin,
                self.primaryLayer,
                int(self.GetGridCoordi(round(cx - mWidth/2.0))),
                int(self.GetGridCoordi(round(cy - mWidth/2.0))),
                int(self.GetGridCoordi(round(cx + mWidth/2.0))),
                int(self.GetGridCoordi(round(cy + mWidth/2.0))))

            dbBPin.setPlacementStatus("LOCKED")

        else:
          # retrive bsInst object.
          # movable instances -> std cell mapping
          if bsType == BsType.MOVABLE_STD_INST:
            curInst = self.movableStdInsts[self.movableStdInstDict[iName]]
          # macro instances
          elif bsType == BsType.MOVABLE_MACRO_INST:
            curInst = self.movableMacroInsts[self.movableMacroInstDict[iName]]
          elif bsType == BsType.FIXED_INST:
            curInst = self.fixedInsts[self.fixedInstDict[iName]]

          # skip for non-feasible standard cells.
          # either movable STD inst or fixed STD inst
          if bsType == BsType.MOVABLE_STD_INST or (bsType == BsType.FIXED_INST and self.IsMacro(curInst.height) == False):
            # if infeasible, skip to fill in the db
            if curInst.IsFeasible() == False:
              continue

          # direction on ITerm
          if iTermDir == "O":
            dbITerm = curInst.RetrieveOdbOutPin()
          elif iTermDir == "I":
            dbITerm = curInst.RetrieveOdbInPin()

          # connect to net
          self.odbpy.dbITerm.connect(dbITerm, dbNet)
    print("Total %d nets are created in OpenDB" % (netCnt))

  def FillOdbClockNet(self):
    allFFInsts = [l for l in self.allStdInsts if l.odbClkPin != None]
    if len(allFFInsts) > 0:
      dbNet = self.odbpy.dbNet_create(self.odbBlock, self.clkNetName)

      for ffInst in allFFInsts:
        dbITerm = ffInst.odbClkPin
        self.odbpy.dbITerm.connect(dbITerm, dbNet)

      dbBTerm = self.odbpy.dbBTerm_create(dbNet, self.clkNetName)
      dbBTerm.setIoType("INPUT")
      dbBTerm.setSigType("CLOCK")
      dbNet.setSigType("CLOCK")


  def WriteMacroLef(self, lefName):
    self.odbpy.write_macro_lef(self.odbLib, lefName)

