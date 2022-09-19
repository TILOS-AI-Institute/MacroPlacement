import sys
import subprocess as sp


def ExecuteCommand(command):
    print(command)
    sp.call(command, shell=True)


def main(arg1):
    print(arg1, "is parsing...")
    f = open(arg1)
    auxCont = f.read()
    f.close()

    fileList = []
    afterColon = False
    for word in auxCont.split(" "):
        if word == ":":
            afterColon = True
            continue
        if afterColon:
            fileList.append(word.strip())

    print(fileList)

    nodeName = [l for l in fileList if l.endswith("nodes")][0]
    netName = [l for l in fileList if l.endswith("nets")][0]
    plName = [l for l in fileList if l.endswith("pl")][0]
    routeName = [l for l in fileList if l.endswith("route")][0]
    #routeName = nodeName.split(".")[0]+".route"
    benchName = nodeName.split(".")[0]
    print(nodeName, netName, plName, routeName)

    #######################################
    # Nodes Mapping
    #######################################

    f = open(nodeName, "r")
    nodeCont = f.read()
    f.close()

    nameMap = dict()
    instCnt = 0
    pinCnt = 0

    newCont = ""
    isFirst = True
    for curLine in nodeCont.split("\n"):
        wordList = curLine.split()
        if isFirst:
            isFirst = False
            newCont += curLine + "\n"
            continue
        if len(wordList) is 0:
            newCont += "\n"
            continue
        if wordList[0] is "#":
            newCont += curLine + "\n"
            continue
        if wordList[0] == "NumNodes" or wordList[0] == "NumTerminals":
            newCont += curLine + "\n"
            continue

        newWord = ""
        # if len(wordList) >= 4 and wordList[1] is "0" and wordList[2] is "0":
        if len(wordList) >= 4 and wordList[1] is "1" and wordList[2] is "1":
            newWord = "p" + str(pinCnt)
            pinCnt += 1
            # newCont += newWord + " " + wordList[1] + " " + wordList[2] + " " + wordList[3] + "\n"
            #newCont += "  " + newWord + " 0 0 terminal_NI\n"
            newCont += "  " + newWord + " 1 1 terminal_NI\n"
        elif len(wordList) >= 4 and wordList[3] == "terminal":
            #newWord = "p"+str(pinCnt)
            #pinCnt += 1
            newWord = "o" + str(instCnt)
            instCnt += 1
            newCont += "  " + newWord + " " + " ".join(wordList[1:]) + "\n"
        else:
            newWord = "o" + str(instCnt)
            instCnt += 1
            newCont += "  " + newWord + " " + \
                wordList[1] + " " + wordList[2] + "\n"
        nameMap[wordList[0]] = newWord

    f = open(benchName + "_mapped.nodes", "w")
    f.write(newCont)
    f.close()

    newCont = ""
    for key, cont in nameMap.items():
        newCont += "%s %s\n" % (key, cont)
    f = open(benchName + "_mapped.nodemap", "w")
    f.write(newCont)
    f.close()

    #######################################
    # Nets Mapping
    #######################################

    f = open(netName, "r")
    netCont = f.read()
    f.close()

    newCont = ""
    isFirst = True

    netCnt = 0
    netNameMap = dict()

    for curLine in netCont.split("\n"):
        wordList = curLine.split()
        if isFirst:
            isFirst = False
            newCont += curLine + "\n"
            continue
        if len(wordList) is 0:
            newCont += "\n"
            continue
        if wordList[0] is "#":
            newCont += curLine + "\n"
            continue
        if wordList[0] == "NumNets" or wordList[0] == "NumPins":
            newCont += curLine + "\n"
            continue
        if wordList[0] == "NetDegree":
            newWord = "n" + str(netCnt)
            netCnt += 1
            netNameMap[wordList[3]] = newWord
            newCont += " ".join(wordList[0:3]) + " " + newWord + "\n"
            continue

        newCont += "  " + nameMap[wordList[0]] + " " + wordList[1] + \
            " " + wordList[2] + " " + wordList[3] + " " + wordList[4] + "\n"
    f = open(benchName + "_mapped.nets", "w")
    f.write(newCont)
    f.close()

    newCont = ""
    for key, cont in netNameMap.items():
        newCont += "%s %s\n" % (key, cont)
    f = open(benchName + "_mapped.netmap", "w")
    f.write(newCont)
    f.close()

    #######################################
    # DP PL Mapping
    #######################################
    #
    #dpPlName = plName.split(".")[0] + ".ntup.pl"
    #f = open(dpPlName, "r")
    #plCont= f.read()
    # f.close()
    #
    #newCont = ""
    #isFirst = True
    #
    # for curLine in plCont.split("\n"):
    #  wordList = curLine.split()
    #  if isFirst:
    #    isFirst = False
    #    newCont += curLine + "\n"
    #    continue
    #  if len(wordList) is 0:
    #    newCont += "\n"
    #    continue
    #  if wordList[0] is "#":
    #    newCont += curLine + "\n"
    #    continue
    #  if len(wordList) == 5:
    #    newCont += nameMap[ wordList[0] ] + " " + " ".join(wordList[1:5]) + "\n"
    #  elif len(wordList) == 6:
    #    newCont += nameMap[ wordList[0] ] + " " + " ".join(wordList[1:6]) + "\n"
    #
    #f = open(benchName + "_mapped.ntup.pl", "w")
    # f.write(newCont)
    # f.close()
    #
    #######################################
    # GP PL Mapping
    #######################################

    gpPlName = plName.split(".")[0] + ".pl"
    f = open(gpPlName, "r")
    plCont = f.read()
    f.close()

    newCont = ""
    isFirst = True

    for curLine in plCont.split("\n"):
        wordList = curLine.split()
        if isFirst:
            isFirst = False
            newCont += curLine + "\n"
            continue
        if len(wordList) is 0:
            newCont += "\n"
            continue
        if wordList[0] is "#":
            newCont += curLine + "\n"
            continue
        if len(wordList) == 5:
            newCont += nameMap[wordList[0]] + \
                " " + " ".join(wordList[1:5]) + "\n"
        elif len(wordList) == 6:
            newCont += nameMap[wordList[0]] + \
                " " + " ".join(wordList[1:6]) + "\n"

    f = open(benchName + "_mapped.pl", "w")
    f.write(newCont)
    f.close()

    #######################################
    # ROUTE Mapping
    #######################################

    f = open(routeName, "r")
    routeCont = f.read()
    f.close()

    newCont = ""
    isFirst = True

    for curLine in routeCont.split("\n"):
        wordList = curLine.split()
        if isFirst:
            isFirst = False
            newCont += curLine + "\n"
            continue
        if len(wordList) is 0:
            newCont += "\n"
            continue
        if wordList[0] is "#":
            newCont += curLine + "\n"
            continue
        if ":" in wordList:
            newCont += curLine + "\n"
            continue
        newCont += "  " + nameMap[wordList[0]] + "  " + \
            "  ".join(wordList[1:len(wordList)]) + "\n"

    f = open(benchName + "_mapped.route", "w")
    f.write(newCont)
    f.close()

    #######################################
    # scl, wts Mapping
    #######################################

    ExecuteCommand("cp %s.scl %s.scl" % (benchName, benchName + "_mapped"))
    ExecuteCommand("cp %s.wts %s.wts" % (benchName, benchName + "_mapped"))

    #######################################
    # shapes Mapping
    #######################################

    f1 = open(benchName + "_mapped.nodemap", "r")
    linesMap = f1.readlines()
    f1.close()

    listOrigName = []
    listMapName = []
    for line in linesMap:
        listOrigName.append(line.split()[0])
        listMapName.append(line.split()[1])

    f2 = open(benchName + ".shapes", "r")
    linesShapes = f2.readlines()
    f2.close()
    # Search mapping name from '.nodemap' file.

    f = open(benchName + "_mapped.shapes", "w")
    for line in linesShapes:
        if len(line.split()) > 1:
            if ':' == line.split()[1] and line.split()[
                    0] != 'NumNonRectangularNodes':
                origName = line.split()[0]
                idxMap = listOrigName.index(origName)
                f.write('%s  :  %s\n' % (listMapName[idxMap], line.split()[2]))
                continue
            else:
                f.write(line)
        else:
            f.write(line)

    f.close()

    #######################################
    # aux writing
    #######################################

    f = open(benchName + "_mapped.aux", "w")
    newCont = "RowBasedPlacement : %s_mapped.nodes %s_mapped.nets %s_mapped.wts %s_mapped.pl %s_mapped.scl %s_mapped.shapes %s_mapped.route" % (
        benchName, benchName, benchName, benchName, benchName, benchName, benchName)
    f.write(newCont)
    f.close()
