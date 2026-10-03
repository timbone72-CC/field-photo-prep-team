package com.inandout.fieldphotoprep.team.internal;

import android.Manifest;
import android.app.*;
import android.content.pm.PackageManager;
import android.graphics.BitmapFactory;
import android.os.*;
import android.view.*;
import android.widget.*;
import androidx.annotation.NonNull;
import androidx.camera.core.*;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.lifecycle.*;
import java.io.File;
import java.util.*;

/** Any-order items, one CameraX owner and a durable reservation before each shutter. */
public final class PhotoActivity extends Activity implements LifecycleOwner {
    private final LifecycleRegistry lifecycle=new LifecycleRegistry(this);
    private TeamRuntime runtime;
    private SupabaseApi.AuthSession session;
    private long generation;
    private String wo,run,item="";
    private LinearLayout root, content;
    private TextView message, counter;
    private ProcessCameraProvider provider;
    private Camera camera;
    private ImageCapture capture;
    private boolean busy, cameraScreen, torch;
    private int flash=ImageCapture.FLASH_MODE_AUTO;
    private Button shutter;
    private PhotoRequirements requirements;
    @NonNull @Override public Lifecycle getLifecycle(){return lifecycle;}
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
        runtime=TeamRuntime.get(this);session=runtime.sessions.load();generation=runtime.sessions.generation();
        wo=getIntent().getStringExtra("wo");run=getIntent().getStringExtra("run");
        if(session==null||wo==null||run==null){finish();return;}
        root=new LinearLayout(this);root.setOrientation(LinearLayout.VERTICAL);root.setPadding(dp(12),dp(12),dp(12),dp(12));
        root.setOnApplyWindowInsetsListener((v,insets)-> {
            int top=insets.getSystemWindowInsetTop(),bottom=insets.getSystemWindowInsetBottom();
            v.setPadding(dp(12),top+dp(12),dp(12),bottom+dp(12));return insets;
        });
        message=new TextView(this);message.setTextSize(15);root.addView(message);
        content=new LinearLayout(this);content.setOrientation(LinearLayout.VERTICAL);root.addView(content,new LinearLayout.LayoutParams(-1,0,1));setContentView(root);
        showItems();
    }
    @Override protected void onStart(){super.onStart();lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_START);}
    @Override protected void onResume(){super.onResume();lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_RESUME);if(content!=null&&!cameraScreen)showItems();}
    @Override protected void onPause(){lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE);super.onPause();}
    @Override protected void onStop(){lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_STOP);super.onStop();}
    @Override protected void onDestroy(){lifecycle.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY);if(provider!=null)provider.unbindAll();super.onDestroy();}
    private boolean current(){return !isDestroyed()&&!isFinishing()&&runtime.sessions.matches(generation,session.userId,session.organizationId);}
    private void ui(Runnable work){runOnUiThread(()->{if(current())work.run();else if(!isDestroyed())finish();});}
    private Button button(String label,LinearLayout target,Runnable work){Button b=new Button(this);b.setText(label);target.addView(b);b.setOnClickListener(v->work.run());return b;}
    private TextView text(String value,LinearLayout target){TextView t=new TextView(this);t.setText(value);t.setTextSize(17);t.setPadding(0,dp(5),0,dp(5));target.addView(t);return t;}
    private void showItems(){
        cameraScreen=false;if(provider!=null)provider.unbindAll();camera=null;capture=null;torch=false;
        runtime.photos.io.execute(()->{
            CachedWorkOrder row=runtime.dao.find(session.userId,session.organizationId,wo,run);
            if(row==null){ui(this::finish);return;}
            List<ProtectedPhoto> photos=runtime.dao.photos(session.userId,session.organizationId,wo,run);
            try{PhotoRequirements req=PhotoRequirements.parse(row.requirementSnapshotJson);List<FieldAction> actions=runtime.dao.actions(session.userId,session.organizationId);ui(()->renderItems(row,req,photos,actions));}
            catch(Exception e){ui(()->{content.removeAllViews();message.setText(e.getMessage());});}
        });
    }
    private void renderItems(CachedWorkOrder row,PhotoRequirements req,List<ProtectedPhoto> photos,List<FieldAction> actions){
        requirements=req;content.removeAllViews();message.setText(row.woNumber+" · Photos");
        ScrollView scroll=new ScrollView(this);LinearLayout list=new LinearLayout(this);list.setOrientation(LinearLayout.VERTICAL);scroll.addView(list);content.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        text(req.summary(),list);int total=0;for(ProtectedPhoto p:photos)if(p.readable())total++;
        text("Saved photos: "+total+" · Delivery pending",list);
        boolean started=!row.startedAt.isEmpty(), complete=false;
        for(FieldAction a:actions)if(a.workOrderId.equals(wo)&&a.runId.equals(run)){if("START".equals(a.kind))started=true;if("COMPLETE".equals(a.kind))complete=true;}
        boolean frozen=complete||photos.stream().anyMatch(p->!p.finishSetId.isEmpty());
        if(frozen)text("Finish saved. Originals are protected while delivery is pending.",list);
        if(!row.conflictReason.isEmpty())text("Needs review. Your photos are preserved. Contact Admin.",list);
        if(!BuildConfig.FIELD_SYNC_ENABLED)text("Recovery mode: saved evidence is read only.",list);
        boolean editable=started&&BuildConfig.FIELD_SYNC_ENABLED&&!frozen&&row.conflictReason.isEmpty()
                &&!"FIELD_COMPLETE".equals(row.fieldStatus)&&!"CANCELLED".equals(row.fieldStatus);
        for(PhotoRequirements.Item i:req.items)if(i.enabled){int count=0;for(ProtectedPhoto p:photos)if(p.readable()&&p.itemId.equals(i.id))count++;
            Button b=button((count>=i.minimum?"✓ ":"")+i.label+"  "+count+"/"+i.minimum,list,()->{item=i.id;openCamera();});b.setEnabled(editable);}
        Button extra=button("Extra photos",list,()->{item="";openCamera();});extra.setEnabled(editable);
        for(ProtectedPhoto p:photos)if(!"DISCARDED".equals(p.state)){
            LinearLayout rowView=new LinearLayout(this);rowView.setOrientation(LinearLayout.HORIZONTAL);list.addView(rowView);
            ImageView thumbnail=new ImageView(this);BitmapFactory.Options options=new BitmapFactory.Options();options.inSampleSize=16;
            thumbnail.setImageBitmap(BitmapFactory.decodeFile(p.originalPath,options));rowView.addView(thumbnail,new LinearLayout.LayoutParams(dp(64),dp(64)));
            PhotoRequirements.Item i=req.enabledItem(p.itemId);Button review=button((i==null?"Extra":i.label)+" · "+("WAITING".equals(p.state)?"Saved":p.state),rowView,()->review(p,editable));
            review.setLayoutParams(new LinearLayout.LayoutParams(0,-2,1));
        }
        button("Back to work order",content,this::finish);
    }
    private void review(ProtectedPhoto p,boolean editable){
        ImageView image=new ImageView(this);BitmapFactory.Options o=new BitmapFactory.Options();o.inSampleSize=4;image.setImageBitmap(BitmapFactory.decodeFile(p.originalPath,o));image.setAdjustViewBounds(true);
        AlertDialog.Builder dialog=new AlertDialog.Builder(this).setTitle("Saved photo").setView(image).setPositiveButton("Keep",null);
        if(editable&&p.finishSetId.isEmpty()&&!"CAPTURING".equals(p.state))dialog.setNegativeButton("Discard…",(d,w)->new AlertDialog.Builder(this)
            .setTitle("Discard this photo?").setMessage("This removes this photo and its count. You can take a replacement before Finish.")
            .setNegativeButton("Keep",null).setPositiveButton("Discard",(dd,ww)->runtime.photos.io.execute(()->{
                try{runtime.photos.discard(session,generation,p.id);ui(this::showItems);}catch(Exception e){ui(()->message.setText(e.getMessage()));}
            })).show());
        dialog.show();
    }
    private void openCamera(){
        if(checkSelfPermission(Manifest.permission.CAMERA)!=PackageManager.PERMISSION_GRANTED){requestPermissions(new String[]{Manifest.permission.CAMERA},8);return;}
        cameraScreen=true;content.removeAllViews();PhotoRequirements.Item selected=requirements.enabledItem(item);
        counter=text(selected==null?"Extra photos":selected.label,content);
        if(selected!=null&&!selected.instruction.isEmpty())text(selected.instruction,content);
        PreviewView preview=new PreviewView(this);content.addView(preview,new LinearLayout.LayoutParams(-1,0,1));
        LinearLayout controls=new LinearLayout(this);content.addView(controls);
        Button flashButton=button("Flash Auto",controls,()->{if(capture!=null){flash=flash==ImageCapture.FLASH_MODE_AUTO?ImageCapture.FLASH_MODE_ON:flash==ImageCapture.FLASH_MODE_ON?ImageCapture.FLASH_MODE_OFF:ImageCapture.FLASH_MODE_AUTO;capture.setFlashMode(flash);}});
        flashButton.setOnClickListener(v->{if(capture==null)return;flash=flash==ImageCapture.FLASH_MODE_AUTO?ImageCapture.FLASH_MODE_ON:flash==ImageCapture.FLASH_MODE_ON?ImageCapture.FLASH_MODE_OFF:ImageCapture.FLASH_MODE_AUTO;capture.setFlashMode(flash);flashButton.setText(flash==ImageCapture.FLASH_MODE_AUTO?"Flash Auto":flash==ImageCapture.FLASH_MODE_ON?"Flash On":"Flash Off");});
        Button torchButton=button("Torch Off",controls,()->{});torchButton.setOnClickListener(v->{if(camera!=null){torch=!torch;camera.getCameraControl().enableTorch(torch);torchButton.setText(torch?"Torch On":"Torch Off");}});
        button("1×",controls,()->{if(camera!=null)camera.getCameraControl().setZoomRatio(1f);});
        Button wide=button("Wide",controls,()->{if(camera!=null){ZoomState z=camera.getCameraInfo().getZoomState().getValue();if(z!=null)camera.getCameraControl().setZoomRatio(z.getMinZoomRatio());}});
        ScaleGestureDetector zoom=new ScaleGestureDetector(this,new ScaleGestureDetector.SimpleOnScaleGestureListener(){@Override public boolean onScale(ScaleGestureDetector detector){
            if(camera!=null){ZoomState z=camera.getCameraInfo().getZoomState().getValue();if(z!=null)camera.getCameraControl().setZoomRatio(Math.max(z.getMinZoomRatio(),Math.min(z.getMaxZoomRatio(),z.getZoomRatio()*detector.getScaleFactor())));}return true;}});
        preview.setOnTouchListener((v,e)->{zoom.onTouchEvent(e);return true;});
        shutter=button("Take photo",content,this::take);shutter.setMinHeight(dp(64));shutter.setEnabled(false);
        button("Done · choose another item",content,()->{if(!busy)showItems();});
        com.google.common.util.concurrent.ListenableFuture<ProcessCameraProvider> future=ProcessCameraProvider.getInstance(this);
        future.addListener(()->{
            if(!current()||!cameraScreen)return;
            try{
                provider=future.get();provider.unbindAll();Preview usePreview=new Preview.Builder().build();usePreview.setSurfaceProvider(preview.getSurfaceProvider());
                capture=new ImageCapture.Builder().setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY).setFlashMode(flash).build();
                camera=provider.bindToLifecycle(this,CameraSelector.DEFAULT_BACK_CAMERA,usePreview,capture);camera.getCameraControl().enableTorch(false);
                boolean hasFlash=camera.getCameraInfo().hasFlashUnit();flashButton.setEnabled(hasFlash);torchButton.setEnabled(hasFlash);if(!hasFlash){capture.setFlashMode(ImageCapture.FLASH_MODE_OFF);flashButton.setText("Flash unavailable");}
                ZoomState z=camera.getCameraInfo().getZoomState().getValue();boolean hasWide=z!=null&&z.getMinZoomRatio()<1f;wide.setEnabled(hasWide);
                if(selected!=null&&"WIDE".equals(selected.framing)){if(hasWide)camera.getCameraControl().setZoomRatio(z.getMinZoomRatio());else message.setText("Wide view unavailable. Use the normal camera and stand farther back.");}
                shutter.setEnabled(BuildConfig.FIELD_SYNC_ENABLED);updateCounter();
            }catch(Exception e){message.setText("Camera unavailable. Your saved photos are protected.");}
        },androidx.core.content.ContextCompat.getMainExecutor(this));
    }
    private void take(){
        if(busy||capture==null||!current()||!BuildConfig.FIELD_SYNC_ENABLED)return;
        busy=true;shutter.setEnabled(false);ImageCapture owner=capture;
        runtime.photos.io.execute(()->{
            try{
                ProtectedPhoto p=runtime.photos.reserve(session,generation,wo,run,item);
                runOnUiThread(()->{
                    if(!current()||!cameraScreen||capture!=owner){runtime.photos.io.execute(()->runtime.photos.captured(p.id));return;}
                    owner.setTargetRotation(getWindowManager().getDefaultDisplay().getRotation());
                    try { owner.takePicture(new ImageCapture.OutputFileOptions.Builder(new File(p.originalPath)).build(),androidx.core.content.ContextCompat.getMainExecutor(this),new ImageCapture.OnImageSavedCallback(){
                        @Override public void onImageSaved(@NonNull ImageCapture.OutputFileResults result){saved(p.id);}
                        @Override public void onError(@NonNull ImageCaptureException error){saved(p.id);}
                    }); } catch(RuntimeException e) { saved(p.id); }
                });
            }catch(Exception e){ui(()->{busy=false;shutter.setEnabled(true);message.setText(e.getMessage());});}
        });
    }
    private void saved(String id){runtime.photos.io.execute(()->{runtime.photos.captured(id);ProtectedPhoto p=runtime.dao.photo(id);ui(()->{
        busy=false;if(cameraScreen){shutter.setEnabled(true);message.setText(p!=null&&p.readable()?"Saved. Take another photo or tap Done.":"Photo did not save correctly. Check saved photos.");updateCounter();}
    });});}
    private void updateCounter(){runtime.photos.io.execute(()->{int n=0;for(ProtectedPhoto p:runtime.dao.photos(session.userId,session.organizationId,wo,run))if(p.readable()&&p.itemId.equals(item))n++;final int count=n;ui(()->{if(cameraScreen){PhotoRequirements.Item selected=requirements.enabledItem(item);counter.setText(selected==null?"Extra · "+count+" saved":selected.label+" · "+count+"/"+selected.minimum);}});});}
    @Override public void onRequestPermissionsResult(int request,@NonNull String[] permissions,@NonNull int[] grants){super.onRequestPermissionsResult(request,permissions,grants);if(request==8&&grants.length>0&&grants[0]==PackageManager.PERMISSION_GRANTED)openCamera();else message.setText("Camera permission is needed to take photos. Saved photos remain protected.");}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
}
