
cimport lib

from wstring cimport wstring, toWideString,wideToString
from libcpp.string cimport string
from libc.stddef cimport wchar_t

from fractions import Fraction


HRESULTS = lib.get_hrmap()

cdef object resolver = None

cdef dict OBJECT_MAP = {}

cdef object error_check(int ret):
    if not lib.SUCCEEDED(ret):
        message = "Unknown Error"
        if HRESULTS.has_key(ret):
            message =  HRESULTS[ret]
    
        raise Exception("failed with [%d]: %s" % (ret, message))
    
    return ret

cdef object query_interface(lib.IUnknown **src, lib.IUnknown **dst, lib.GUID guid):
    if not src[0]:
        raise Exception("src cannot be a null pointer")
    error_check(src[0].QueryInterface(guid, <void**> dst))

cdef object register():
    print "registering"
    error_check(lib.AAFLoad(NULL))
    cdef lib.IAAFPluginManager *plugin_manager
    
    error_check(lib.AAFGetPluginManager(&plugin_manager))
    error_check(plugin_manager.RegisterSharedPlugins())
    plugin_manager.Release()
    

cdef lib.aafCharacter* aafChar(char* s):
    
    cdef wstring wstr = toWideString(s)
    
    return <lib.aafCharacter *> wstr.c_str()

cdef char* toChar(lib.aafCharacter* s):
    
    cdef wstring wstr = wstring(<wchar_t*>s)
    
    cdef string mbs = wideToString(wstr)
    
    return <char *> mbs.c_str()

cdef object register_object(object obj):
    global OBJECT_MAP
    OBJECT_MAP[obj.__name__] = obj

cdef object lookup_object(bytes name):
    global OBJECT_MAP
    rename = name
    for n,r in (("",""), ("Definition", "Def")):
        rename = rename.replace(n,r)
        if OBJECT_MAP.has_key(rename):
            return OBJECT_MAP[rename]
    raise KeyError("No object named %s" % name)

def set_resolver(object obj):
    global resolver
    resolver = obj

cdef object resolve_object(object obj): 
    return resolver(obj)

cdef object fraction_to_aafRational(object obj, lib.aafRational_t& r):
    
    f = Fraction(obj)
    r.numerator = f.numerator
    r.denominator = f.denominator
    
cdef class MobID(object):
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.to_string(),
            id(self),
        )

    def to_string(self):
        
        f = b"urn:smpte:umid:%02x%02x%02x%02x.%02x%02x%02x%02x.%02x%02x%02x%02x." + \
             "%02x"  + \
             "%02x%02x%02x." + \
             "%02x%02x%02x%02x.%02x%02x%02x%02x.%08x.%04x%04x"
        mobID = self.mobID
        return f % (
             mobID.SMPTELabel[0], mobID.SMPTELabel[1], mobID.SMPTELabel[2],  mobID.SMPTELabel[3],
             mobID.SMPTELabel[4], mobID.SMPTELabel[5], mobID.SMPTELabel[6],  mobID.SMPTELabel[7],
             mobID.SMPTELabel[8], mobID.SMPTELabel[9], mobID.SMPTELabel[10], mobID.SMPTELabel[11],
             mobID.length,
             mobID.instanceHigh, mobID.instanceMid, mobID.instanceLow,
             mobID.material.Data4[0], mobID.material.Data4[1], mobID.material.Data4[2], mobID.material.Data4[3],
             mobID.material.Data4[4], mobID.material.Data4[5], mobID.material.Data4[6], mobID.material.Data4[7],
             mobID.material.Data1, mobID.material.Data2, mobID.material.Data3)
        