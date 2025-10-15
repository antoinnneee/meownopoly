import os
import sys
import cv2
import torch
import numpy as np
from pathlib import Path
from PIL import Image, ImageFilter
from torchvision import transforms
from tqdm import tqdm
import logging
from transformers import AutoModelForImageSegmentation
import huggingface_hub

# Add BiRefNet to path
sys.path.insert(0, str(Path(__file__).parent / "BiRefNet-main"))
from models.birefnet import BiRefNet

# Try to load python-dotenv if available (optional)
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # dotenv not installed, will use environment variables only

# Hugging Face authentication token for RMBG-2.0 model
# Priority: 1) Environment variable, 2) .env file, 3) Hardcoded (not recommended)
HUGGINGFACE_TOKEN = os.getenv('HUGGINGFACE_TOKEN', '')

# Parent folder path
PARENT_FOLDER = Path(r"C:\Users\Valere\CONVERTOR_VIDEO")
# Input folder for videos
INPUT_FOLDER = PARENT_FOLDER / "drop_mp4_here"
# Logs folder
LOGS_FOLDER = PARENT_FOLDER / "logs"

# Create logs folder if it doesn't exist
LOGS_FOLDER.mkdir(exist_ok=True)

# Setup logging with timestamped log file
from datetime import datetime
log_filename = LOGS_FOLDER / f"video_processing_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_filename, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Log session start
logger.info("="*80)
logger.info(f"New session started - Log file: {log_filename}")
logger.info("="*80)


def ask_yes_no(question, default="y"):
    """
    Ask a yes/no question and return True for yes, False for no.
    Case insensitive. Accepts y/n or yes/no.
    """
    while True:
        response = input(f"{question} [{'Y/n' if default.lower() == 'y' else 'y/N'}]: ").strip()
        if not response:
            response = default
        response = response.lower()
        if response in ['y', 'yes', 'o', 'oui']:
            return True
        elif response in ['n', 'no', 'non']:
            return False
        else:
            print("Réponse invalide. Veuillez répondre par 'y' (oui) ou 'n' (non).")


def get_processing_size(original_size, max_size=1024):
    """
    Calculate processing size while maintaining aspect ratio.
    Ensures the longest side doesn't exceed max_size.
    """
    width, height = original_size
    aspect_ratio = width / height
    
    if width > height:
        new_width = max_size
        new_height = int(max_size / aspect_ratio)
    else:
        new_height = max_size
        new_width = int(max_size * aspect_ratio)
    
    # Ensure dimensions are divisible by 32 for better model performance
    new_width = (new_width // 32) * 32
    new_height = (new_height // 32) * 32
    
    return (new_width, new_height)


def refine_mask(mask, threshold=0.5, apply_morphology=True):
    """
    Refine the mask to improve edge quality and remove noise.
    """
    # Convert to numpy array
    mask_array = np.array(mask).astype(np.float32) / 255.0
    
    # Apply threshold to create clearer separation
    mask_array = np.where(mask_array > threshold, mask_array, 0)
    
    # Slightly enhance the mask values for better visibility
    mask_array = np.clip(mask_array * 1.1, 0, 1)
    
    # Convert back to PIL
    mask_refined = Image.fromarray((mask_array * 255).astype(np.uint8))
    
    if apply_morphology:
        # Apply slight blur to smooth edges
        mask_refined = mask_refined.filter(ImageFilter.GaussianBlur(radius=0.5))
    
    return mask_refined


def extract_frames(video_path, output_folder):
    logger.info(f"Extracting frames from: {video_path.name}")
    logger.info(f"Output folder: {output_folder}")
    output_folder.mkdir(parents=True, exist_ok=True)
    cap = cv2.VideoCapture(str(video_path))
    
    if not cap.isOpened():
        logger.error(f"Failed to open video: {video_path}")
        raise ValueError(f"Cannot open video: {video_path}")
    
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    
    logger.info(f"Video properties: {width}x{height}, {fps} fps, {total_frames} frames")
    logger.info(f"Video codec: {cap.get(cv2.CAP_PROP_FOURCC)}")
    
    frame_count = 0
    with tqdm(total=total_frames, desc="Extracting frames", unit="frame") as pbar:
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            frame_filename = output_folder / f"frame_{frame_count:05d}.png"
            cv2.imwrite(str(frame_filename), frame)
            frame_count += 1
            pbar.update(1)
    
    cap.release()
    logger.info(f"Extraction complete: {frame_count} frames extracted")
    return frame_count, fps


def remove_background_from_frames(input_folder, output_folder, total_frames, is_reprocessing=False, model_choice='birefnet1024'):
    if is_reprocessing:
        logger.info("RE-PROCESSING: Removing background again for better transparency...")
    else:
        logger.info("Removing background from frames using BiRefNet...")
    output_folder.mkdir(parents=True, exist_ok=True)
    frame_files = sorted(input_folder.glob("frame_*.png"))
    
    if len(frame_files) == 0:
        raise ValueError(f"No frames found in {input_folder}")
    
    logger.info("Loading BiRefNet model (state-of-the-art for background removal)...")
    logger.info("First run may take time to download model from Hugging Face")
    
    # Load BiRefNet model once for all frames
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    logger.info(f"Using device: {device}")
    if device.type == 'cuda':
        logger.info(f"GPU: {torch.cuda.get_device_name(0)}")
        logger.info(f"GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
    
    try:
        if model_choice == 'rmbg2':
            # Load RMBG-2.0 (BRIA AI commercial-grade model)
            logger.info("Loading RMBG-2.0 model from Hugging Face...")
            logger.info("Note: RMBG-2.0 is a commercial-grade model with excellent quality")
            
            # Login to Hugging Face with token
            logger.info("Authenticating with Hugging Face...")
            huggingface_hub.login(HUGGINGFACE_TOKEN)
            logger.info("Authentication successful!")
            
            model = AutoModelForImageSegmentation.from_pretrained('briaai/RMBG-2.0', trust_remote_code=True)
            model.to(device)
            model.eval()
            model_resolution = 1024
            model_type = 'rmbg'
            logger.info("RMBG-2.0 model loaded successfully!")
            logger.info("Using 1024x1024 processing (adaptive aspect ratio)")
        elif model_choice == 'birefnet512':
            # Load BiRefNet_512x512 (512x512 optimized model - faster)
            logger.info("Loading BiRefNet_512x512 model from Hugging Face...")
            logger.warning("Note: 512 model is faster but may have lower quality on complex backgrounds")
            model = BiRefNet.from_pretrained('zhengpeng7/BiRefNet_512x512')
            model.to(device)
            model.eval()
            model_resolution = 512
            model_type = 'birefnet'
            logger.info("BiRefNet_512x512 model loaded successfully!")
            logger.info("Using 512x512 model for faster processing")
        else:  # birefnet1024
            # Load BiRefNet standard model (best quality)
            logger.info("Loading BiRefNet standard model (1024x1024) from Hugging Face...")
            model = BiRefNet.from_pretrained('zhengpeng7/BiRefNet')
            model.to(device)
            model.eval()
            model_resolution = 1024
            model_type = 'birefnet'
            logger.info("BiRefNet standard model loaded successfully!")
            logger.info("Using 1024x1024 model for best quality")
        
        logger.info(f"Model moved to {device}")
        
        # Set precision for better performance
        torch.set_float32_matmul_precision('high')
        logger.info("Precision set to 'high' for optimal performance")
        
    except Exception as e:
        logger.error(f"Error loading model: {e}", exc_info=True)
        raise
    
    # Use autocast for better performance
    autocast_ctx = torch.amp.autocast(device_type='cuda', dtype=torch.float16) if device.type == 'cuda' else torch.amp.autocast(device_type='cpu', enabled=False)
    
    logger.info("Model loaded. Processing frames with high-quality background removal...")
    if model_choice == 'birefnet512':
        logger.info("Processing resolution: 512x512 (fixed size for BiRefNet_512x512 model)")
    else:
        logger.info(f"Processing resolution: max {model_resolution}px (adaptive, maintains aspect ratio)")
    logger.info(f"Total frames to process: {len(frame_files)}")
    
    # Normalization transform
    normalize = transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
    
    # Process first frame with detailed logging
    first_frame = True
    
    with tqdm(total=len(frame_files), desc="Removing background", unit="frame") as pbar:
        for idx, frame_file in enumerate(frame_files):
            try:
                # Load and prepare image
                input_image = Image.open(frame_file).convert("RGB")
                original_size = input_image.size
                
                if first_frame:
                    logger.info(f"First frame: {frame_file.name}")
                    logger.info(f"Original size: {original_size}")
                
                # Calculate processing size based on model
                if model_choice == 'birefnet512':
                    # For 512 model: force exact 512x512 (no aspect ratio preservation)
                    processing_size = (512, 512)
                    if first_frame:
                        logger.info(f"Processing size: {processing_size} (forced 512x512 for BiRefNet_512x512 model)")
                else:
                    # For 1024 models: preserve aspect ratio
                    processing_size = get_processing_size(original_size, max_size=model_resolution)
                    if first_frame:
                        logger.info(f"Processing size: {processing_size} (aspect ratio preserved)")
                
                # Resize for processing
                input_resized = input_image.resize(processing_size, Image.LANCZOS)
                
                # Convert to tensor and normalize
                input_tensor = transforms.ToTensor()(input_resized)
                input_tensor = normalize(input_tensor)
                input_tensor = input_tensor.unsqueeze(0).to(device)
                
                if first_frame:
                    logger.info(f"Input tensor shape: {input_tensor.shape}")
                
                # Predict mask
                with autocast_ctx, torch.no_grad():
                    if model_type == 'rmbg':
                        # RMBG model
                        preds = model(input_tensor)
                        # Handle nested structure from RMBG
                        while isinstance(preds, (list, tuple)):
                            preds = preds[-1]
                        pred = preds.sigmoid().to(torch.float32).cpu().squeeze()
                    else:
                        # BiRefNet model
                        preds = model(input_tensor)[-1].sigmoid().to(torch.float32).cpu()
                        pred = preds.squeeze()
                
                if first_frame:
                    logger.info(f"Prediction shape: {pred.shape}")
                    logger.info(f"Mask value range: [{pred.min():.3f}, {pred.max():.3f}]")
                    logger.info(f"Mask mean: {pred.mean():.3f}")
                
                # Convert to PIL
                pred_pil = transforms.ToPILImage()(pred)
                
                # Resize back to original size with high-quality interpolation
                mask = pred_pil.resize(original_size, Image.LANCZOS)
                
                if first_frame:
                    mask_array = np.array(mask)
                    logger.info(f"Mask after resize - range: [{mask_array.min()}, {mask_array.max()}], mean: {mask_array.mean():.1f}")
                
                # Refine the mask to improve quality
                # Adjust threshold based on model
                if model_choice == 'birefnet512':
                    threshold = 0.3  # 512 model needs higher threshold
                elif model_choice == 'rmbg2':
                    threshold = 0.15  # RMBG-2.0 is very precise, use lower threshold
                else:
                    threshold = 0.2  # BiRefNet 1024 standard
                
                if first_frame:
                    logger.info(f"Using threshold: {threshold} (model: {model_choice})")
                
                mask = refine_mask(mask, threshold=threshold, apply_morphology=True)
                
                if first_frame:
                    mask_array = np.array(mask)
                    logger.info(f"Mask after refinement - range: [{mask_array.min()}, {mask_array.max()}], mean: {mask_array.mean():.1f}")
                
                # Apply mask to create transparent background
                input_image = Image.open(frame_file).convert("RGBA")
                # Use the mask directly as the alpha channel for transparency
                input_image.putalpha(mask)
                
                # Save with transparency
                output_filename = output_folder / frame_file.name
                input_image.save(output_filename, "PNG")
                
                if first_frame:
                    logger.info(f"First frame saved: {output_filename}")
                    logger.info(f"Output file size: {output_filename.stat().st_size / 1024:.1f} KB")
                    first_frame = False
                
                # Clean up
                input_image.close()
                
            except Exception as e:
                logger.error(f"Error processing {frame_file.name}: {e}", exc_info=True)
                raise
            
            pbar.update(1)
    
    logger.info(f"Background removal complete: {len(frame_files)} frames processed")
    logger.info("BiRefNet provides excellent quality for transparent backgrounds!")
    
    # Log GPU memory usage if CUDA
    if device.type == 'cuda':
        logger.info(f"GPU memory allocated: {torch.cuda.memory_allocated(0) / 1024**2:.1f} MB")
        logger.info(f"GPU memory reserved: {torch.cuda.memory_reserved(0) / 1024**2:.1f} MB")


def create_animated_webp(input_folder, output_file, fps):
    logger.info("="*60)
    logger.info("Creating animated WebP...")
    logger.info(f"Input folder: {input_folder}")
    logger.info(f"Output file: {output_file}")
    frame_files = sorted(input_folder.glob("frame_*.png"))
    
    if len(frame_files) == 0:
        logger.error(f"No frames found in {input_folder}")
        raise ValueError(f"No frames found in {input_folder}")
    
    duration_ms = int(1000 / fps)
    
    logger.info(f"Total frames: {len(frame_files)}")
    logger.info(f"FPS: {fps}, Duration per frame: {duration_ms}ms")
    logger.info("Loading and processing frames...")
    logger.info("This may take a while, please wait...")
    
    try:
        # Load frames with better memory management
        frames = []
        with tqdm(total=len(frame_files), desc="Loading frames", unit="frame") as pbar:
            for frame_file in frame_files:
                img = Image.open(frame_file)
                # Ensure RGBA mode for transparency
                if img.mode != 'RGBA':
                    img = img.convert('RGBA')
                # Load into memory to avoid file handle issues
                img.load()
                frames.append(img)
                pbar.update(1)
        
        if len(frames) == 0:
            raise ValueError("No frames loaded")
        
        logger.info(f"Saving animated WebP: {output_file.name}")
        logger.info(f"Parameters: {len(frames)} frames, {duration_ms}ms per frame")
        logger.info("Encoding WebP... This may take several minutes for many frames")
        
        # Save with more robust parameters
        frames[0].save(
            str(output_file),
            format='WEBP',
            save_all=True,
            append_images=frames[1:],
            duration=duration_ms,
            loop=0,
            quality=85,
            method=4,
            lossless=False,
            allow_mixed=True
        )
        
        # Verify file was created and has content
        if not output_file.exists():
            raise ValueError("WebP file was not created")
        
        file_size = output_file.stat().st_size
        if file_size == 0:
            raise ValueError("WebP file is empty")
        
        file_size_mb = file_size / (1024 * 1024)
        logger.info(f"Animated WebP created successfully: {file_size_mb:.2f} MB")
        
    finally:
        # Clean up memory - close all image handles
        for frame in frames:
            try:
                frame.close()
            except:
                pass


def reprocess_background_removal(frames_no_bg_folder, output_webp, fps, video_name, auto_mode=True, model_choice='birefnet1024'):
    """
    Reprocess frames that already have background removed to improve transparency.
    This applies BiRefNet again on the already processed frames.
    Can loop multiple times for iterative improvement.
    """
    while True:
        logger.info(f"\n{'='*80}")
        logger.info(f"RE-TRAITEMENT: {video_name}")
        logger.info(f"{'='*80}")
        
        if not frames_no_bg_folder.exists():
            logger.error(f"Folder {frames_no_bg_folder} does not exist!")
            return False
        
        frame_files = sorted(frames_no_bg_folder.glob("frame_*.png"))
        if len(frame_files) == 0:
            logger.error(f"No frames found in {frames_no_bg_folder}")
            return False
        
        try:
            # Create temporary folder for reprocessed frames
            temp_folder = frames_no_bg_folder.parent / "frames_no_bg_temp"
            temp_folder.mkdir(exist_ok=True)
            
            logger.info(f"Re-processing {len(frame_files)} frames for better transparency...")
            
            # Use the existing function but with frames_no_bg as input
            remove_background_from_frames(frames_no_bg_folder, temp_folder, len(frame_files), is_reprocessing=True, model_choice=model_choice)
            
            # Replace old frames with new ones
            logger.info("Replacing frames with improved versions...")
            for frame_file in frame_files:
                frame_file.unlink()  # Delete old frame
            
            for temp_frame in sorted(temp_folder.glob("frame_*.png")):
                temp_frame.rename(frames_no_bg_folder / temp_frame.name)
            
            # Remove temp folder
            temp_folder.rmdir()
            
            # Delete old webp and create new one
            if output_webp.exists():
                output_webp.unlink()
            
            create_animated_webp(frames_no_bg_folder, output_webp, fps)
            logger.info(f"\nSUCCESS: {video_name} re-processed successfully!")
            logger.info(f"  Result: {output_webp}")
            
            # Ask if user wants to reprocess again (loop)
            if not auto_mode:
                if not ask_yes_no("Voulez-vous retraiter encore une fois ?", default="n"):
                    break  # Exit the loop
            else:
                break  # In auto mode, only process once
            
        except Exception as e:
            logger.error(f"\nERROR re-processing {video_name}: {e}")
            return False
    
    return True


def process_video(video_path, auto_mode=True, model_choice='birefnet1024'):
    logger.info(f"\n{'='*80}")
    logger.info(f"PROCESSING: {video_path.name}")
    logger.info(f"{'='*80}")
    
    video_name = video_path.stem
    output_base = PARENT_FOLDER / video_name
    
    frames_folder = output_base / "frames"
    frames_no_bg_folder = output_base / "frames_no_bg"
    output_webp = output_base / "output.webp"
    
    # Check if video folder exists (already processed)
    video_folder_exists = output_base.exists()
    already_processed = output_webp.exists()
    
    if already_processed:
        logger.info(f"Video {video_name} already processed")
        logger.info(f"Existing file: {output_webp}")
        
        # In interactive mode, ALWAYS ask if user wants to reprocess
        if not auto_mode:
            if ask_yes_no("Voulez-vous retraiter la suppression de fond ?", default="n"):
                # Get fps from existing video
                cap = cv2.VideoCapture(str(video_path))
                fps = cap.get(cv2.CAP_PROP_FPS)
                cap.release()
                reprocess_background_removal(frames_no_bg_folder, output_webp, fps, video_name, auto_mode=auto_mode, model_choice=model_choice)
        return "skipped"
    
    # Check if folder exists but no webp (incomplete processing)
    elif video_folder_exists and not already_processed:
        logger.info(f"Folder exists for {video_name} but no output.webp found")
        
        # Check if frames_no_bg exists
        if frames_no_bg_folder.exists() and len(list(frames_no_bg_folder.glob("frame_*.png"))) > 0:
            logger.info("frames_no_bg folder exists, will regenerate WebP")
            # Get fps from original video
            cap = cv2.VideoCapture(str(video_path))
            fps = cap.get(cv2.CAP_PROP_FPS)
            cap.release()
            
            try:
                create_animated_webp(frames_no_bg_folder, output_webp, fps)
                logger.info(f"\nSUCCESS: WebP regenerated for {video_name}")
                logger.info(f"  Result: {output_webp}")
                
                # Ask if user wants to reprocess
                if not auto_mode:
                    if ask_yes_no("Voulez-vous retraiter la suppression de fond ?", default="n"):
                        reprocess_background_removal(frames_no_bg_folder, output_webp, fps, video_name, auto_mode=auto_mode, model_choice=model_choice)
                
                return "success"
            except Exception as e:
                logger.error(f"Error regenerating WebP: {e}")
                # Continue to full processing
    
    # Full processing (new video or incomplete)
    output_base.mkdir(parents=True, exist_ok=True)
    
    try:
        total_frames, fps = extract_frames(video_path, frames_folder)
        remove_background_from_frames(frames_folder, frames_no_bg_folder, total_frames, is_reprocessing=False, model_choice=model_choice)
        create_animated_webp(frames_no_bg_folder, output_webp, fps)
        logger.info(f"\nSUCCESS: {video_name} processed successfully!")
        logger.info(f"  Result: {output_webp}")
        
        # Ask if user wants to reprocess
        if not auto_mode:
            if ask_yes_no("Voulez-vous retraiter la suppression de fond ?", default="n"):
                reprocess_background_removal(frames_no_bg_folder, output_webp, fps, video_name, auto_mode=auto_mode, model_choice=model_choice)
        
        return "success"
        
    except Exception as e:
        logger.error(f"\nERROR processing {video_name}: {e}")
        raise


def main():
    logger.info("="*80)
    logger.info("VIDEO BACKGROUND REMOVAL SCRIPT")
    logger.info("="*80)
    logger.info(f"Python version: {sys.version}")
    logger.info(f"PyTorch version: {torch.__version__}")
    logger.info(f"CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        logger.info(f"CUDA version: {torch.version.cuda}")
        logger.info(f"GPU: {torch.cuda.get_device_name(0)}")
    
    if not INPUT_FOLDER.exists():
        logger.warning(f"Folder {INPUT_FOLDER} does not exist. Creating...")
        INPUT_FOLDER.mkdir(parents=True, exist_ok=True)
        logger.info(f"Folder created: {INPUT_FOLDER}")
        logger.info("Place your MP4 files in this folder and run the script again.")
        return
    
    video_files = list(INPUT_FOLDER.glob("*.mp4"))
    
    if len(video_files) == 0:
        logger.info(f"\nNo MP4 files found in {INPUT_FOLDER}")
        logger.info("Place your MP4 files in this folder and run the script again.")
        return
    
    logger.info(f"\n{len(video_files)} video(s) found:")
    for i, video_file in enumerate(video_files, 1):
        logger.info(f"  {i}. {video_file.name}")
    
    # Ask for automatic mode
    print("\n" + "="*80)
    auto_mode = ask_yes_no("Mode automatique ?", default="y")
    
    # Choose model based on mode
    if auto_mode:
        logger.info("Mode automatique activé - traitement sans interruption")
        logger.info("Utilisation du modèle BiRefNet_512x512 (rapide)")
        model_choice = 'birefnet512'
    else:
        logger.info("Mode interactif activé - questions après chaque vidéo")
        print("\nChoisissez le modèle de suppression de fond:")
        print("  1. BiRefNet 1024x1024 (meilleure qualité, plus lent)")
        print("  2. BiRefNet 512x512 (rapide, qualité correcte)")
        print("  3. RMBG-2.0 (commercial-grade, excellent qualité, 1024x1024)")
        print()
        
        while True:
            choice = input("Votre choix (1/2/3) [1]: ").strip() or "1"
            if choice in ["1", "2", "3"]:
                break
            print("Choix invalide. Veuillez choisir 1, 2 ou 3.")
        
        if choice == "1":
            model_choice = 'birefnet1024'
            logger.info("→ Modèle BiRefNet 1024x1024 sélectionné (meilleure qualité)")
        elif choice == "2":
            model_choice = 'birefnet512'
            logger.info("→ Modèle BiRefNet 512x512 sélectionné (plus rapide)")
            logger.warning("→ Note: Le modèle 512 peut avoir des problèmes sur certaines images complexes")
        else:
            model_choice = 'rmbg2'
            logger.info("→ Modèle RMBG-2.0 sélectionné (commercial-grade, excellent)")
    
    logger.info(f"Model configuration: {model_choice}")
    logger.info(f"Input folder: {INPUT_FOLDER}")
    logger.info(f"Output folder: {PARENT_FOLDER}")
    
    print("="*80 + "\n")
    
    successful = 0
    failed = 0
    skipped = 0
    
    for video_file in video_files:
        try:
            result = process_video(video_file, auto_mode=auto_mode, model_choice=model_choice)
            
            if result == "success":
                successful += 1
            elif result == "skipped":
                skipped += 1
            
        except KeyboardInterrupt:
            logger.warning("\n\nUser interruption detected")
            logger.info(f"Progress: {successful} success, {failed} failed, {skipped} skipped")
            sys.exit(0)
        except Exception as e:
            failed += 1
            logger.error(f"Failed to process {video_file.name}")
            logger.error(f"Error: {e}")
            continue
    
    logger.info("\n" + "="*80)
    logger.info("PROCESSING COMPLETE")
    logger.info("="*80)
    logger.info(f"Videos processed successfully: {successful}")
    logger.info(f"Videos skipped (already processed): {skipped}")
    logger.info(f"Videos failed: {failed}")
    logger.info(f"Total: {successful + failed + skipped}")
    
    if failed > 0:
        logger.warning(f"\n{failed} video(s) could not be processed. Check logs above.")
    
    # Log session summary
    logger.info("="*80)
    logger.info("Session ended successfully")
    logger.info(f"Log file saved: {log_filename}")
    logger.info("="*80)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.warning("\n\nProgram interrupted by user (Ctrl+C)")
        logger.info(f"Log file saved: {log_filename}")
        sys.exit(0)
    except Exception as e:
        logger.error("="*80)
        logger.error("FATAL ERROR")
        logger.error("="*80)
        logger.error(f"Fatal error: {e}", exc_info=True)
        logger.error(f"Log file saved: {log_filename}")
        logger.error("="*80)
        sys.exit(1)
