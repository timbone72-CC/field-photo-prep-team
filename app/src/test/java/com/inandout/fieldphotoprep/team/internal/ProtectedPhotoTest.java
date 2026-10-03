package com.inandout.fieldphotoprep.team.internal;
import static org.junit.Assert.*;
import android.content.Context;
import android.graphics.Bitmap;
import androidx.room.Room;
import org.json.*;
import org.junit.*;
import org.junit.runner.RunWith;
import org.robolectric.*;
import org.robolectric.annotation.Config;
import java.io.*;
import java.util.*;
@RunWith(RobolectricTestRunner.class) @Config(sdk=34)
public class ProtectedPhotoTest {
    TeamDatabase db; CachedWorkOrderDao dao; RoomAssignmentStore store;
    final SupabaseApi.AuthSession actor=OfflineActionTest.session("a","org");
    Context context; File directory; PhotoOwner owner; SessionCoordinator sessions;
    @Before public void setup() throws Exception {
        context=RuntimeEnvironment.getApplication();directory=new File(context.getCacheDir(),"photo-test-"+UUID.randomUUID());assertTrue(directory.mkdirs());
        db=Room.inMemoryDatabaseBuilder(context,TeamDatabase.class).allowMainThreadQueries().build();dao=db.cachedWorkOrderDao();store=new RoomAssignmentStore(dao);
        SupabaseApi.WorkOrder work=OfflineActionTest.wo("1","instance");work.requirementSnapshotJson=PhotoRequirementsTest.configuration(3,1,1).toString();store.replace(actor,List.of(work),1);
        dao.createAction(actor,"1","run-1","START","2026-10-03T12:00:00Z");
        context.getSharedPreferences(SecureSessionStore.PREFERENCES_NAME,Context.MODE_PRIVATE).edit().clear().commit();
        SecureSessionStore secure=new SecureSessionStore(context,new SecureSessionStore.Crypto(){public byte[] encrypt(byte[] v){return v;}public byte[] decrypt(byte[] v){return v;}});
        sessions=new SessionCoordinator(secure,t->actor);sessions.install(sessions.beginLogin(),actor);owner=new PhotoOwner(context,dao,sessions);
    }
    @After public void close(){owner.io.shutdownNow();db.close();for(File f:Objects.requireNonNull(directory.listFiles()))f.delete();directory.delete();}
    ProtectedPhoto reservation(String item) {
        String id=UUID.randomUUID().toString();return dao.reservePhoto(actor,"1","run-1",item,"2026-10-03T12:00:10Z",id,new File(directory,id+".jpg").getAbsolutePath(),new File(directory,id+"-prep.jpg").getAbsolutePath());
    }
    void jpeg(ProtectedPhoto p) throws Exception {Bitmap b=Bitmap.createBitmap(64,32,Bitmap.Config.ARGB_8888);try(FileOutputStream o=new FileOutputStream(p.originalPath)){assertTrue(b.compress(Bitmap.CompressFormat.JPEG,95,o));}b.recycle();}
    ProtectedPhoto photo(String item) throws Exception {ProtectedPhoto p=reservation(item);jpeg(p);owner.captured(p.id);return dao.photo(p.id);}
    @Test public void onePhotoCreditsOneItemAndExtraCreditsTotalWithAtomicFrozenIntent() throws Exception {
        ProtectedPhoto a=photo(PhotoRequirementsTest.id(2));assertTrue(a.readable());
        assertThrows(IllegalStateException.class,()->dao.createAction(actor,"1","run-1","COMPLETE","2026-10-03T12:01:00Z"));
        photo(PhotoRequirementsTest.id(3));assertThrows(IllegalStateException.class,()->dao.createAction(actor,"1","run-1","COMPLETE","2026-10-03T12:01:00Z"));
        photo("");FieldAction finish=dao.createAction(actor,"1","run-1","COMPLETE","2026-10-03T12:01:00Z");
        assertEquals(3,new JSONArray(finish.finishPhotosJson).length());assertFalse(finish.finishSetId.isEmpty());
        for(ProtectedPhoto p:dao.photos("a","org","1","run-1"))assertEquals(finish.finishSetId,p.finishSetId);
        assertEquals(finish.actionId,dao.createAction(actor,"1","run-1","COMPLETE","2026-10-03T12:02:00Z").actionId);
        assertThrows(IllegalStateException.class,()->reservation(""));assertThrows(IllegalStateException.class,()->dao.beginDiscard(actor,a.id));owner.ensureFrozenReadable(finish);
    }
    @Test public void interruptedNonemptyCaptureIsPreservedAndEmptyCaptureDoesNotCount() throws Exception {
        ProtectedPhoto p=reservation(PhotoRequirementsTest.id(2));jpeg(p);owner.recover();assertTrue(dao.photo(p.id).readable());assertTrue(new File(p.originalPath).isFile());
        ProtectedPhoto empty=reservation("");owner.captured(empty.id);assertEquals("DISCARDED",dao.photo(empty.id).state);
        assertEquals(1,dao.photos("a","org","1","run-1").stream().filter(ProtectedPhoto::readable).count());
    }
    @Test public void discardIntentAndWrongAccountCannotDropOrRebindPhotos() throws Exception {
        ProtectedPhoto p=photo(PhotoRequirementsTest.id(2));
        assertThrows(IllegalStateException.class,()->dao.beginDiscard(OfflineActionTest.session("b","org"),p.id));
        dao.beginDiscard(actor,p.id);PhotoOwner restarted=new PhotoOwner(context,dao,sessions);restarted.recover();restarted.io.shutdownNow();
        assertEquals("DISCARDED",dao.photo(p.id).state);assertFalse(new File(p.originalPath).exists());
    }
    @Test public void requirementRaceProtectsSnapshotAndPhotosInsteadOfReplacingCache() throws Exception {
        ProtectedPhoto p=photo(PhotoRequirementsTest.id(2));SupabaseApi.WorkOrder changed=OfflineActionTest.wo("1","instance");
        JSONObject j=PhotoRequirementsTest.configuration(3,1,1);j.put("revision",PhotoRequirementsTest.id(90));changed.requirementSnapshotJson=j.toString();store.replace(actor,List.of(changed),2);
        assertEquals("REQUIREMENTS_CHANGED",dao.find("a","org","1","run-1").conflictReason);assertTrue(new File(p.originalPath).exists());
        assertEquals(PhotoRequirementsTest.id(1),PhotoRequirements.parse(dao.find("a","org","1","run-1").requirementSnapshotJson).revision);
        assertThrows(IllegalStateException.class,()->reservation(""));
    }
    @Test public void preparingASeparateCopyNeverMutatesTheOriginal() throws Exception {
        ProtectedPhoto p=reservation("");jpeg(p);byte[] before=java.nio.file.Files.readAllBytes(new File(p.originalPath).toPath());owner.captured(p.id);
        assertArrayEquals(before,java.nio.file.Files.readAllBytes(new File(p.originalPath).toPath()));
        assertTrue(dao.photo(p.id).readable());assertNotEquals(p.originalPath,p.preparedPath);
    }
}
