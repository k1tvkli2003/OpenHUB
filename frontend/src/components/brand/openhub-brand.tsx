import { cn } from "@/lib/utils";

export type OpenHubMarkProps = {
  className?: string;
  size?: number;
  decorative?: boolean;
};

export function OpenHubMark({ className, size = 32, decorative = true }: OpenHubMarkProps) {
  return (
    <img
      src="/openhub-route-hub.png"
      width={size}
      height={size}
      alt={decorative ? "" : "OpenHUB"}
      aria-hidden={decorative || undefined}
      className={cn("shrink-0 object-contain", className)}
    />
  );
}

export type OpenHubWordmarkProps = {
  className?: string;
  decorative?: boolean;
};

export function OpenHubWordmark({ className, decorative = false }: OpenHubWordmarkProps) {
  return (
    <img
      src="/openhub-wordmark.png"
      alt={decorative ? "" : "OpenHUB"}
      aria-hidden={decorative || undefined}
      className={cn("h-auto object-contain", className)}
    />
  );
}
