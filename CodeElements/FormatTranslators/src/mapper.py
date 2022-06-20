from BookshelfToOdb import BookshelfToOdb
import odb
import os
import sys
sys.path.append('./utils')

def PreProcessNanGate45(db, ffClkPinList):
  for lib in db.getLibs():
    for master in lib.getMasters():
      for mTerm in master.getMTerms():
        if mTerm.getName() in ffClkPinList:
          master.setSequential(1)
          print("[INFO] Set %s as sequential masters" %(master.getName()))
          break



def MapNanGate45(file_dir, lef_list, design, util_dir):
    db = odb.dbDatabase.create()
    for lef in lef_list:
        odb.read_lef(db, lef)

    PreProcessNanGate45(db, ['CK'])
    bs = BookshelfToOdb(opendbpy = odb,
        opendb = db, file_dir = file_dir,
        auxName = "%s.aux" % (design),
        siteName = 'FreePDK45_38x28_10R_NP_162NW_34O',
        macroInstObsLayer = ['metal1', 'via1', 'metal2', 'via2'],
        macroInstPinLayer = ['metal3', 'metal4'],
        primaryLayer = 'metal3',
        mastersFileName = util_dir + '/cellList_ng45.txt',
        ffClkPinList = ['CK'],
        customFPRatio = 1.2)

    bs.WriteMacroLef('%s_macro.lef' %(design))
    odb.write_def(db.getChip().getBlock(), '%s.def' % (design))
    odb.write_db(db, '%s.db' % (design))


def MapASAP7(file_dir, lef_list, design, util_dir):
    db = odb.dbDatabase.create()
    for lef in lef_list:
        odb.read_lef(db, lef)

    PreProcessNanGate45(db, ['CLK'])
    bs = BookshelfToOdb(opendbpy = odb,
         opendb = db,
         file_dir = file_dir,
         auxName = "%s.aux" % (design),
         siteName = 'asap7sc7p5t',
         macroInstObsLayer = ['M1', 'V1', 'M2', 'V2'],
         macroInstPinLayer = ['M3', 'M4'],
         primaryLayer = 'M3',
         mastersFileName = util_dir + '/cellList_asap7.txt',
         ffClkPinList = ['CLK'],
         targetFFRatio = 0.18,
         customFPRatio = 1.2)

    bs.WriteMacroLef('%s_macro.lef' %(design))
    odb.write_def(db.getChip().getBlock(), '%s.def' % (design))
    odb.write_db(db, '%s.db' % (design))
