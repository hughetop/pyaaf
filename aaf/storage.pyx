
cimport lib
cimport mob
cimport iterator
from base cimport AAFBase, AAFObject
from dictionary cimport Dictionary

from .util cimport error_check, query_interface, register_object, lookup_object, AUID, MobID
from .iterator cimport EssenceDataIter
from .mob cimport Mob
from wstring cimport wstring,toWideString
import os

cdef class IAAFFileProxy(AAFBase):
    def __init__(self):
        self.ptr= NULL
        self.iid = lib.IID_IAAFFile
        
    cdef object setup(self):
        super(IAAFFileProxy, self).__init__(self)

    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    def __dealloc__(self):
        if self.ptr:
            ret = self.ptr.Close()
            if not (ret == lib.AAFRESULT_SUCCESS or ret == lib.AAFRESULT_NOT_OPEN):
                error_check(ret)
            self.ptr.Release()
        
cdef class File(object):
    
    def __init__(self, bytes path, bytes mode = b'r'):
        """
        Open a AAF file, returning a File Object. Mode is similar to python's native open command.
        Possible modes are: 
            'r' readonly, 
            'w' write 
            'rw' readwrite
            't' transient (in memory)
        If the file is opened in 'w' or 'rw', save needs to be called to write the changes to the file.
        Note: Opening a .xml file in 'r' and 'rw' mode is buggy and might not work
        """
        
        self.proxy = IAAFFileProxy()
        
        if not path:
            path = b""
        
        cdef wstring w_path = toWideString(path)
        
        mode = mode.lower()
        
        if mode == 'r':
            error_check(lib.AAFFileOpenExistingRead(w_path.c_str(),
                                                    0,
                                                    &self.proxy.ptr))
        elif mode == 'rw':
            self.setup_new_file(path, mode)
        elif mode == 'w':
            self.setup_new_file(path, mode)
        elif mode == 't':
            self.setup_new_file(path, mode)
        else:
            raise ValueError("invalid mode: %s" % mode)
        self.mode = mode
        self.proxy.setup()
        
    cdef object setup_new_file(self, bytes path, bytes mode=b'w'):
            
        # setup product id
        cdef lib.aafUID_t productUID
        productUID.Data1 = 0x97e04c67
        productUID.Data2 = 0xdbe6
        productUID.Data3 = 0x4d11
        for i,value in enumerate((0xbc,0xd7,0x3a,0x3a,0x42,0x53,0xa2,0xef)):
            productUID.Data4[i] = value

        productInfo = self.productInfo
        
        company_name = "CompanyName"
        product_name = "pyaaf"
        producr_version_string = "0"
        
        productInfo.companyName = <lib.aafCharacter* > toWideString(company_name).c_str()
        productInfo.productName = <lib.aafCharacter* > toWideString(product_name).c_str()
        productInfo.productVersionString = <lib.aafCharacter* > toWideString(producr_version_string).c_str()
        productInfo.productID = productUID
        
        cdef wstring w_path = toWideString(path)
        cdef lib.aafUID_t kind = lib.kAAFFileKind_Aaf4KBinary
        
        if mode == 'rw' and os.path.exists(path):
            #d = dict(productUID)
            error_check(lib.AAFFileOpenExistingModify(w_path.c_str(),
                                                      0, &productInfo,
                                                      &self.proxy.ptr))
            return
        
        elif mode == 't':
            error_check(lib.AAFFileOpenTransient(&productInfo, &self.proxy.ptr))
            return

        if os.path.exists(path):
            os.remove(path)
        
        name, ext = os.path.splitext(path)
        
        
        
        if ext.lower() in ('.xml'):
            kind = lib.kAAFFileKind_AafXmlText
        
        error_check(lib.AAFFileOpenNewModifyEx(w_path.c_str(), 
                                               &kind, 0, &productInfo, 
                                               &self.proxy.ptr))
    def save(self,bytes path=None):
        """Save AAF file to disk. If not path and the mode is 'rw' or 'w' it will overwrite or modify
        the current file. If path is supplied a new file will be created, (Save Copy As).
        If the extension of the path is .xml a xml file will be saved.
        Note: If file mode is 't' or 'r' and path is None, nothing will happen
        """
        if not path:
            # If in 't' or 'r' mode do nothing
            if self.mode == 'rw' or self.mode == 'w':
                error_check(self.proxy.ptr.Save())
            return
        
        cdef File new_file = File(path, 'w')
        
        error_check(self.proxy.ptr.SaveCopyAs(new_file.proxy.ptr))
        
        return new_file
        

    
    def close(self):
        error_check(self.proxy.ptr.Close())
        
    property header:
        def __get__(self):
            cdef Header header = Header()
            error_check(self.proxy.ptr.GetHeader(&header.ptr))
            return Header(header)
            
    property storage:
        def __get__(self):
            return self.header.storage()
    
    property dictionary:
        def __get__(self):
            return self.header.dictionary()

cdef class Header(AAFObject):
    def __init__(self, AAFBase obj = None):
        super(Header, self).__init__(obj)
        self.iid = lib.IID_IAAFHeader
        self.auid = lib.AUID_AAFHeader
        self.ptr = NULL
        if not obj:
            return
        
        query_interface(obj.get_ptr(), <lib.IUnknown **> &self.ptr, lib.IID_IAAFHeader)
    
    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
            
    def append(self, AAFObject obj):
        cdef mob.Mob mob_obj
        
        if isinstance(obj, mob.Mob):
            mob_obj = obj
            error_check(self.ptr.AddMob(mob_obj.ptr))
        else:
            raise ValueError("unable to append type %s" %(type(obj)))
        
    def dictionary(self):
        cdef Dictionary dictionary = Dictionary()
        error_check(self.ptr.GetDictionary(&dictionary.ptr))
        return Dictionary(dictionary)

    def storage(self,none=None):

        cdef ContentStorage content_storage = ContentStorage()
        error_check(self.ptr.GetContentStorage(&content_storage.ptr))
        
        return ContentStorage(content_storage)
    
         
cdef class ContentStorage(AAFObject):
    def __init__(self, AAFBase obj = None):
        super(ContentStorage, self).__init__(obj)
        self.iid = lib.IID_IAAFContentStorage
        self.auid = lib.AUID_AAFContentStorage
        self.ptr = NULL
        if not obj:
            return
        
        query_interface(obj.get_ptr(), <lib.IUnknown **> &self.ptr, lib.IID_IAAFContentStorage)
    
    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
        
    def count_mobs(self):
        cdef lib.aafUInt32 mobCount
        error_check(self.ptr.CountMobs(lib.kAAFAllMob, &mobCount))
        return mobCount
    
    def essence_data(self):
        cdef EssenceDataIter data_iter = EssenceDataIter()
        
        error_check(self.ptr.EnumEssenceData(&data_iter.ptr))
        return data_iter
        
    def lookup_mob(self, mobID):
        """
        Looks up the Mob that matches the given mob id
        """
        
        cdef Mob mob = Mob()
        cdef MobID mobID_obj = MobID(mobID)
        
        error_check(self.ptr.LookupMob(mobID_obj.mobID, &mob.ptr))
        
        return Mob(mob).resolve()
        

    def mobs(self):
        cdef iterator.MobIter mob_iter = iterator.MobIter()
        
        cdef lib.aafSearchCrit_t search_crit
        
        search_crit.searchTag = lib.kAAFByMobKind
        search_crit.tags.mobKind = lib.kAAFAllMob
        
        error_check(self.ptr.GetMobs(&search_crit, &mob_iter.ptr))
        return mob_iter
    
    def master_mobs(self):
        cdef iterator.MobIter mob_iter = iterator.MobIter()
        
        cdef lib.aafSearchCrit_t search_crit
        
        search_crit.searchTag = lib.kAAFByMobKind
        search_crit.tags.mobKind = lib.kAAFMasterMob
        
        error_check(self.ptr.GetMobs(&search_crit, &mob_iter.ptr))
        return mob_iter
    
    def composition_mobs(self):
        cdef iterator.MobIter mob_iter = iterator.MobIter()
        
        cdef lib.aafSearchCrit_t search_crit
        
        search_crit.searchTag = lib.kAAFByMobKind
        search_crit.tags.mobKind = lib.kAAFCompMob
        
        error_check(self.ptr.GetMobs(&search_crit, &mob_iter.ptr))
        return mob_iter
    
    def toplevel_mobs(self):
        cdef iterator.MobIter mob_iter = iterator.MobIter()
        
        cdef lib.aafSearchCrit_t search_crit
        
        search_crit.searchTag = lib.kAAFByCompositionMobUsageCode
        search_crit.tags.usageCode = lib.kAAFUsage_TopLevel
        
        error_check(self.ptr.GetMobs(&search_crit, &mob_iter.ptr))
        return mob_iter
    
cdef class Identification(AAFObject):
    def __init__(self, AAFBase obj = None):
        super(Identification, self).__init__(obj)
        self.iid = lib.IID_IAAFIdentification
        self.auid = lib.AUID_AAFIdentification
        self.ptr = NULL
        if not obj:
            return
        
        query_interface(obj.get_ptr(), <lib.IUnknown **> &self.ptr, self.iid)
    
    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
    
        
register_object(Header)
register_object(ContentStorage)
register_object(Identification)

# Handy alias.
open = File
