export const ResizeUpload = {
  mounted() {
    this.el.addEventListener("change", (e) => {
      if (this.el.dataset.resized === "true") {
        this.el.dataset.resized = "false";
        return;
      }

      const file = e.target.files[0];
      if (!file || !file.type.startsWith("image/")) return;

      const maxDimension = 1200;
      const targetMaxBytes = 1 * 1024 * 1024; // Strict target: Maximum 1 MB

      const reader = new FileReader();
      reader.readAsDataURL(file);
      reader.onload = (event) => {
        const img = new Image();
        img.src = event.target.result;
        img.onload = () => {
          let width = img.width;
          let height = img.height;

          if (width > height) {
            if (width > maxDimension) {
              height = Math.round((height * maxDimension) / width);
              width = maxDimension;
            }
          } else {
            if (height > maxDimension) {
              width = Math.round((width * maxDimension) / height);
              height = maxDimension;
            }
          }

          const canvas = document.createElement("canvas");
          canvas.width = width;
          canvas.height = height;

          const ctx = canvas.getContext("2d");
          ctx.drawImage(img, 0, 0, width, height);

          // Helper function to compress and check size iteratively
          const attemptCompress = (quality) => {
            canvas.toBlob(
              (blob) => {
                if (!blob) return;

                // If file is still > 1MB and quality can be reduced further, step down quality
                if (blob.size > targetMaxBytes && quality > 0.3) {
                  attemptCompress(quality - 0.15);
                  return;
                }

                const resizedFile = new File(
                  [blob],
                  file.name.replace(/\.[^/.]+$/, ".jpg"),
                  {
                    type: "image/jpeg",
                    lastModified: Date.now(),
                  }
                );

                const dataTransfer = new DataTransfer();
                dataTransfer.items.add(resizedFile);

                this.el.dataset.resized = "true";
                this.el.files = dataTransfer.files;
                this.el.dispatchEvent(new Event("change", { bubbles: true }));
              },
              "image/jpeg",
              quality
            );
          };

          // Start compression attempt at 80% quality
          attemptCompress(0.8);
        };
      };
    });
  }
};
